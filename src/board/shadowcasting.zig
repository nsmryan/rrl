const std = @import("std");
const testing = std.testing;
const debug = std.debug;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const math = @import("math");
const Pos = math.pos.Pos;

pub const Error = error{Overflow} || Allocator.Error;

/// Compute FOV information for a given position using the shadow mapping algorithm.
///
/// This uses the is_blocking function pointer, which checks whether a given position is
/// blocked (such as by a wall), given the position and the 'map' argument.
/// is_blocking: fn (Pos, @TypeOf(map)) bool;
///
/// This type cannot be used in some cases, such as a slice constructed from an array, so it is an anytype
/// instead.
///
pub fn computeFov(origin: Pos, map: anytype, visible: *ArrayList(Pos), comptime is_blocking: anytype) Error!void {
    // Mark the origin as visible.
    try mark_visible(origin, visible);

    var index: usize = 0;
    while (index < 4) : (index += 1) {
        const quadrant = Quadrant.new(Cardinal.from_index(index), origin);

        const first_row = Row.new(1, Rational.new(-1, 1), Rational.new(1, 1));

        try Scan(@TypeOf(map), is_blocking).scan(first_row, quadrant, map, visible);
    }
}

fn Scan(comptime MapType: type, comptime is_blocking: anytype) type {
    return struct {
        fn scan(input_row: Row, quadrant: Quadrant, map: MapType, visible: *ArrayList(Pos)) Error!void {
            var prev_tile: ?Pos = null;

            var row = input_row;

            var iter: RowIter = row.tiles();
            while (iter.next()) |tile| {
                const tile_is_wall = is_blocking(quadrant.transform(tile), map);
                const tile_is_floor = !tile_is_wall;

                var prev_is_wall = false;
                var prev_is_floor = false;
                if (prev_tile) |prev| {
                    prev_is_wall = is_blocking(quadrant.transform(prev), map);
                    prev_is_floor = !prev_is_wall;
                }

                if (tile_is_wall or try is_symmetric(row, tile)) {
                    const pos = quadrant.transform(tile);

                    try mark_visible(pos, visible);
                }

                if (prev_is_wall and tile_is_floor) {
                    row.start_slope = slope(tile);
                }

                if (prev_is_floor and tile_is_wall) {
                    var next_row = row.next();
                    next_row.end_slope = slope(tile);

                    try Scan(MapType, is_blocking).scan(next_row, quadrant, map, visible);
                }

                prev_tile = tile;
            }

            if (prev_tile) |tile| {
                if (!is_blocking(quadrant.transform(tile), map)) {
                    try Scan(MapType, is_blocking).scan(row.next(), quadrant, map, visible);
                }
            }
        }
    };
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

        const min_col = round_ties_up(depth_times_start);

        const max_col = round_ties_down(depth_times_end);

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

fn is_symmetric(row: Row, tile: Pos) error{Overflow}!bool {
    const col = tile.y;

    const depth_times_start = Rational.new(row.depth, 1).mult(row.start_slope);
    const depth_times_end = Rational.new(row.depth, 1).mult(row.end_slope);

    const col_rat = Rational.new(col, 1);

    const symmetric = (try col_rat.gteq(depth_times_start)) and (try col_rat.lteq(depth_times_end));

    return symmetric;
}

fn round_ties_up(n: Rational) i32 {
    return (n.add(Rational.new(1, 2))).floor();
}

fn round_ties_down(n: Rational) i32 {
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

fn inside_map(pos: Pos, map: []const []const i32) bool {
    const is_inside = pos.x >= 0 and pos.y >= 0 and @intCast(usize, pos.y) < map.len and @intCast(usize, pos.x) < map[0].len;
    return is_inside;
}

fn matchingVisible(expected: []const []const i32, visible: *ArrayList(Pos)) !void {
    var y: usize = 0;
    while (y < expected.len) : (y += 1) {
        var x: usize = 0;
        while (x < expected[0].len) : (x += 1) {
            try std.testing.expectEqual(expected[y][x] == 1, contains(visible, Pos.init(@intCast(i32, x), @intCast(i32, y))));
        }
    }
}

fn is_blocking_fn(pos: Pos, tiles: []const []const i32) bool {
    return !inside_map(pos, tiles) or tiles[@intCast(usize, pos.y)][@intCast(usize, pos.x)] == 1;
}

fn contains(visible: *ArrayList(Pos), pos: Pos) bool {
    for (visible.items[0..]) |item| {
        if (std.meta.eql(pos, item)) {
            return true;
        }
    }
    return false;
}

//fn mark_visible(pos: Pos, tiles: []const []const i32, visible: *ArrayList(Pos)) !void {
//    if (inside_map(pos, tiles) and !contains(visible, pos)) {
//        try visible.append(pos);
//    }
//}
fn mark_visible(pos: Pos, visible: *ArrayList(Pos)) !void {
    if (!contains(visible, pos)) {
        try visible.append(pos);
    }
}

test "expansive walls" {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var visible = ArrayList(Pos).init(allocator.allocator());
    defer visible.deinit();

    const origin = Pos.init(1, 2);
    const tiles = [_][]const i32{ &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 0, 0, 0, 0, 0, 1 }, &.{ 1, 0, 0, 0, 0, 0, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 } };
    try computeFov(origin, tiles[0..], &visible, &is_blocking_fn);

    const expected = [_][]const i32{ &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 } };
    try matchingVisible(expected[0..], &visible);
}

test "test_expanding_shadows" {
    const origin = Pos.init(0, 0);

    const tiles = [_][]const i32{ &.{ 0, 0, 0, 0, 0, 0, 0 }, &.{ 0, 1, 0, 0, 0, 0, 0 }, &.{ 0, 0, 0, 0, 0, 0, 0 }, &.{ 0, 0, 0, 0, 0, 0, 0 }, &.{ 0, 0, 0, 0, 0, 0, 0 } };

    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var visible = ArrayList(Pos).init(allocator.allocator());
    defer visible.deinit();

    try computeFov(origin, tiles[0..], &visible, &is_blocking_fn);

    const expected = [_][]const i32{ &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 0, 0, 1, 1, 1 }, &.{ 1, 1, 0, 0, 0, 0, 1 }, &.{ 1, 1, 1, 0, 0, 0, 0 } };
    try matchingVisible(expected[0..], &visible);
}

test "test_no_blind_corners" {
    const origin = Pos.init(3, 0);

    const tiles = [_][]const i32{ &.{ 0, 0, 0, 0, 0, 0, 0 }, &.{ 1, 1, 1, 1, 0, 0, 0 }, &.{ 0, 0, 0, 1, 0, 0, 0 }, &.{ 0, 0, 0, 1, 0, 0, 0 } };

    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var visible = ArrayList(Pos).init(allocator.allocator());
    defer visible.deinit();

    try computeFov(origin, tiles[0..], &visible, &is_blocking_fn);

    const expected = [_][]const i32{ &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 1, 1, 1, 1, 1, 1, 1 }, &.{ 0, 0, 0, 0, 1, 1, 1 }, &.{ 0, 0, 0, 0, 0, 1, 1 } };

    try matchingVisible(expected[0..], &visible);
}
