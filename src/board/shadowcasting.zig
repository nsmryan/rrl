const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const DynamicBitSet = std.DynamicBitSet;

const math = @import("math");
const Pos = math.pos.Pos;
const Dims = math.utils.Dims;

const BlockedType = @import("blocking.zig").BlockedType;
const Map = @import("map.zig").Map;
const t = @import("tile.zig");
const Tile = t.Tile;
const Height = Tile.Height;

pub const Error = error{Overflow} || Allocator.Error;

pub const Pov = struct {
    position: Pos,
    dims: Dims,
    visible: DynamicBitSet,

    pub fn init(dims: Dims, allocator: Allocator) !Pov {
        const numTiles = dims.numTiles();
        return Pov{ .position = Pos.init(0, 0), .dims = dims, .visible = try DynamicBitSet.initEmpty(allocator, numTiles) };
    }

    pub fn deinit(pov: *Pov) void {
        pov.visible.deinit();
    }

    pub fn isVisible(pov: *const Pov, position: Pos) bool {
        return pov.visible.isSet(pov.dims.toIndex(position));
    }

    pub fn clear(pov: *Pov) void {
        pov.visible.setRangeValue(std.bit_set.Range{ .start = 0, .end = pov.visible.capacity() }, false);
    }

    pub fn markVisible(pov: *Pov, position: Pos) void {
        const index = pov.dims.toIndex(position);
        pov.visible.set(index);
    }

    pub fn resize(pov: *Pov, dims: Dims) !void {
        pov.dims = dims;
        try pov.visible.resize(dims.numTiles(), false);
    }
};

pub fn isBlocking(position: Pos, map: Map) bool {
    if (map.isWithinBounds(position)) {}
    return !map.isWithinBounds(position) or BlockedType.fov.tileBlocks(map.get(position)) != Height.empty;
}

/// Compute FOV information for a given position using the shadow mapping algorithm.
pub fn computeFov(origin: Pos, map: Map, pov: *Pov) Error!void {
    pov.clear();
    pov.position = origin;
    pov.dims = map.dims();

    // Empty maps need no FoV.
    if (map.width == 0 or map.height == 0) {
        return;
    }

    // Mark the origin as visible.
    markVisible(origin, map, pov);

    var index: usize = 0;
    while (index < 4) : (index += 1) {
        const quadrant = Quadrant.new(Cardinal.from_index(index), origin);

        const first_row = Row.new(1, Rational.new(-1, 1), Rational.new(1, 1));

        try scan(first_row, quadrant, map, pov);
    }
}

fn scan(input_row: Row, quadrant: Quadrant, map: Map, pov: *Pov) Error!void {
    var prev_tile: ?Pos = null;

    var row = input_row;

    var iter: RowIter = row.tiles();
    while (iter.next()) |tile| {
        const tile_is_wall = isBlocking(quadrant.transform(tile), map);
        const tile_is_floor = !tile_is_wall;

        var prev_is_wall = false;
        var prev_is_floor = false;
        if (prev_tile) |prev| {
            prev_is_wall = isBlocking(quadrant.transform(prev), map);
            prev_is_floor = !prev_is_wall;
        }

        if (tile_is_wall or try isSymmetric(row, tile)) {
            const pos = quadrant.transform(tile);

            markVisible(pos, map, pov);
        }

        if (prev_is_wall and tile_is_floor) {
            row.start_slope = slope(tile);
        }

        if (prev_is_floor and tile_is_wall) {
            var next_row = row.next();
            next_row.end_slope = slope(tile);

            try scan(next_row, quadrant, map, pov);
        }

        prev_tile = tile;
    }

    if (prev_tile) |tile| {
        if (!isBlocking(quadrant.transform(tile), map)) {
            try scan(row.next(), quadrant, map, pov);
        }
    }
}

const Cardinal = enum {
    North,
    East,
    South,
    West,

    fn from_index(index: usize) Cardinal {
        const cardinals = [4]Cardinal{ Cardinal.North, Cardinal.East, Cardinal.South, Cardinal.West };
        return cardinals[index];
    }
};

const Quadrant = struct {
    cardinal: Cardinal,
    ox: i32,
    oy: i32,

    fn new(cardinal: Cardinal, origin: Pos) Quadrant {
        return Quadrant{ .cardinal = cardinal, .ox = origin.x, .oy = origin.y };
    }

    fn transform(self: *const Quadrant, tile: Pos) Pos {
        const row = tile.x;
        const col = tile.y;

        switch (self.cardinal) {
            Cardinal.North => {
                return Pos.init(self.ox + col, self.oy - row);
            },

            Cardinal.South => {
                return Pos.init(self.ox + col, self.oy + row);
            },

            Cardinal.East => {
                return Pos.init(self.ox + row, self.oy + col);
            },

            Cardinal.West => {
                return Pos.init(self.ox - row, self.oy + col);
            },
        }
    }
};

const Row = struct {
    depth: i32,
    start_slope: Rational,
    end_slope: Rational,

    fn new(depth: i32, start_slope: Rational, end_slope: Rational) Row {
        return .{ .depth = depth, .start_slope = start_slope, .end_slope = end_slope };
    }

    fn tiles(self: *Row) RowIter {
        const depth_times_start = Rational.new(self.depth, 1).mult(self.start_slope);
        const depth_times_end = Rational.new(self.depth, 1).mult(self.end_slope);

        const min_col = roundTiesUp(depth_times_start);

        const max_col = roundTiesDown(depth_times_end);

        const depth = self.depth;

        return RowIter.new(min_col, max_col, depth);
    }

    fn next(self: *Row) Row {
        return Row.new(self.depth + 1, self.start_slope, self.end_slope);
    }
};

const RowIter = struct {
    min_col: i32,
    max_col: i32,
    depth: i32,
    col: i32,

    pub fn new(min_col: i32, max_col: i32, depth: i32) RowIter {
        return RowIter{ .min_col = min_col, .max_col = max_col, .depth = depth, .col = min_col };
    }

    pub fn next(self: *RowIter) ?Pos {
        if (self.col > self.max_col) {
            return null;
        } else {
            const col = self.col;
            self.col += 1;
            return Pos.init(@intCast(i32, self.depth), @intCast(i32, col));
        }
    }
};

fn slope(tile: Pos) Rational {
    const row_depth = tile.x;
    const col = tile.y;
    return Rational.new(2 * col - 1, 2 * row_depth);
}

fn isSymmetric(row: Row, tile: Pos) error{Overflow}!bool {
    const col = tile.y;

    const depth_times_start = Rational.new(row.depth, 1).mult(row.start_slope);
    const depth_times_end = Rational.new(row.depth, 1).mult(row.end_slope);

    const col_rat = Rational.new(col, 1);

    const symmetric = (try col_rat.gteq(depth_times_start)) and (try col_rat.lteq(depth_times_end));

    return symmetric;
}

fn roundTiesUp(n: Rational) i32 {
    return (n.add(Rational.new(1, 2))).floor();
}

fn roundTiesDown(n: Rational) i32 {
    return (n.sub(Rational.new(1, 2))).ceil();
}

// This is just enough of a Rational type for this library. Zig std lib has a Rational type,
// but it is a BigRational which requires an allocator.
const Rational = struct {
    const Error = error{Overflow};
    num: i32,
    denom: i32,

    pub fn new(num: i32, denom: i32) Rational {
        return Rational{ .num = num, .denom = denom };
    }

    pub fn gteq(self: Rational, other: Rational) Rational.Error!bool {
        const result = ((self.num * other.denom)) >= ((other.num * self.denom));
        return result;
    }

    pub fn lteq(self: Rational, other: Rational) Rational.Error!bool {
        const result = ((self.num * other.denom)) <= ((other.num * self.denom));
        return result;
    }

    pub fn mult(self: Rational, other: Rational) Rational {
        const result = Rational.new(self.num * other.num, self.denom * other.denom);
        return result;
    }

    pub fn add(self: Rational, other: Rational) Rational {
        const result = Rational.new(self.num * other.denom + other.num * self.denom, self.denom * other.denom);
        return result;
    }

    pub fn sub(self: Rational, other: Rational) Rational {
        const result = Rational.new(self.num * other.denom - other.num * self.denom, self.denom * other.denom);
        return result;
    }

    pub fn ceil(self: Rational) i32 {
        if (self.denom != 0) {
            const div = @divFloor(self.num, self.denom);
            const result = div + @boolToInt(@mod(self.num, self.denom) > 0);
            return result;
        } else {
            // Idk whether this can happen for this algorithm.
            return 0;
        }
    }

    pub fn floor(self: Rational) i32 {
        if (self.denom != 0) {
            const result = @divFloor(self.num, self.denom);
            return result;
        } else {
            // Idk whether this can happen for this algorithm.
            return 0;
        }
    }

    pub fn eq(self: Rational, other: Rational) bool {
        return self.num == other.num and self.denom == other.denom;
    }
};

test "Rational ceil" {
    try std.testing.expectEqual(@as(i32, 1), Rational.new(1, 2).ceil());
    try std.testing.expectEqual(@as(i32, 1), Rational.new(1, 1).ceil());
    try std.testing.expectEqual(@as(i32, 0), Rational.new(1, 0).ceil());
}

test "Rational floor" {
    try std.testing.expectEqual(@as(i32, 0), Rational.new(1, 2).floor());
    try std.testing.expectEqual(@as(i32, 1), Rational.new(1, 1).floor());
    try std.testing.expectEqual(@as(i32, 0), Rational.new(1, 0).floor());
}

test "Rational mult" {
    try std.testing.expect(Rational.new(1, 4).eq(Rational.new(1, 2).mult(Rational.new(1, 2))));
    try std.testing.expect(Rational.new(4, 9).eq(Rational.new(2, 3).mult(Rational.new(2, 3))));
}

fn matchingVisible(expected: []const []const i32, pov: *Pov) !void {
    var y: usize = 0;
    while (y < expected.len) : (y += 1) {
        var x: usize = 0;
        while (x < expected[0].len) : (x += 1) {
            const pos = Pos.init(@intCast(i32, x), @intCast(i32, y));
            try std.testing.expectEqual(expected[y][x] == 1, pov.isVisible(pos));
        }
    }
}

fn markVisible(pos: Pos, map: Map, pov: *Pov) void {
    if (map.isWithinBounds(pos)) {
        const index = pov.dims.toIndex(pos);
        pov.visible.set(index);
    }
}

fn makeMap(tiles: []const []const i32, allocator: Allocator) !Map {
    const width = @intCast(i32, tiles[0].len);
    const height = @intCast(i32, tiles.len);
    var map = try Map.fromDims(width, height, allocator);
    for (tiles) |row, y| {
        for (row) |cell, x| {
            if (cell == 1) {
                map.set(Pos.init(@intCast(i32, x), @intCast(i32, y)), Tile.tallWall());
            }
        }
    }
    return map;
}

test "shadowcasting expansive walls" {
    var gp_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gp_allocator.allocator();

    const origin = Pos.init(1, 2);
    const tiles = [_][]const i32{ &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 0, 0, 0, 0, 0, 1 }, &.{ 1, 0, 0, 0, 0, 0, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 } };

    var map = try makeMap(tiles[0..], allocator);
    defer map.deinit();

    var pov = try Pov.init(map.dims(), allocator);
    defer pov.deinit();

    try computeFov(origin, map, &pov);

    const expected = [_][]const i32{ &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 } };
    try matchingVisible(expected[0..], &pov);
}

test "shadowcasting expanding shadows" {
    var gp_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gp_allocator.allocator();

    const origin = Pos.init(0, 0);

    const tiles = [_][]const i32{ &.{ 0, 0, 0, 0, 0, 0, 0 }, &.{ 0, 1, 0, 0, 0, 0, 0 }, &.{ 0, 0, 0, 0, 0, 0, 0 }, &.{ 0, 0, 0, 0, 0, 0, 0 }, &.{ 0, 0, 0, 0, 0, 0, 0 } };

    var map = try makeMap(tiles[0..], allocator);
    defer map.deinit();

    var pov = try Pov.init(map.dims(), allocator);
    defer pov.deinit();

    try computeFov(origin, map, &pov);

    const expected = [_][]const i32{ &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 0, 0, 1, 1, 1 }, &.{ 1, 1, 0, 0, 0, 0, 1 }, &.{ 1, 1, 1, 0, 0, 0, 0 } };
    try matchingVisible(expected[0..], &pov);
}

test "shadowcasting no blind corners" {
    var gp_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gp_allocator.allocator();

    const origin = Pos.init(3, 0);

    const tiles = [_][]const i32{ &.{ 0, 0, 0, 0, 0, 0, 0 }, &.{ 1, 1, 1, 1, 0, 0, 0 }, &.{ 0, 0, 0, 1, 0, 0, 0 }, &.{ 0, 0, 0, 1, 0, 0, 0 } };

    var map = try makeMap(tiles[0..], allocator);
    defer map.deinit();

    var pov = try Pov.init(map.dims(), allocator);
    defer pov.deinit();

    try computeFov(origin, map, &pov);

    const expected = [_][]const i32{ &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 0, 0, 0, 0, 1, 1, 1 }, &.{ 0, 0, 0, 0, 0, 1, 1 } };

    try matchingVisible(expected[0..], &pov);
}
