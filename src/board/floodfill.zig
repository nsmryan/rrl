const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Map = @import("map.zig").Map;
const Tile = @import("tile.zig").Tile;
const Wall = Tile.Wall;

const blocking = @import("blocking.zig");

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const utils = @import("utils");
const Array = utils.buffer.Array;

pub const HitPos = struct {
    pos: Pos,
    force: i32,
};

// TODO reduce force according to a table for blocked/tall wall/short wall costs.
//      use neighbors instead of reachableNeighbors.
//      if we reach a location with more force, add it to current even if already seen.
pub const FloodFill = struct {
    flood: ArrayList(HitPos),
    current: ArrayList(HitPos),

    dampen_tile_blocked: ?i32 = null,
    dampen_short_wall: ?i32 = null,
    dampen_tall_wall: ?i32 = null,

    pub fn init(allocator: Allocator) FloodFill {
        return FloodFill{
            .flood = ArrayList(HitPos).init(allocator),
            .current = ArrayList(HitPos).init(allocator),
        };
    }

    pub fn deinit(floodfill: *FloodFill) void {
        floodfill.flood.deinit();
        floodfill.current.deinit();
    }

    pub fn clear(floodfill: *FloodFill) void {
        floodfill.flood.clearRetainingCapacity();
        floodfill.current.clearRetainingCapacity();
    }

    pub fn fill(floodfill: *FloodFill, map: *const Map, start: Pos, radius: usize) !void {
        floodfill.clear();

        const start_hit_pos = HitPos{ .pos = start, .force = @intCast(i32, radius) };
        try floodfill.current.append(start_hit_pos);
        try floodfill.flood.append(start_hit_pos);

        while (floodfill.current.items.len > 0) {
            const cur = floodfill.current.pop();
            var next_positions = try map.neighbors(cur.pos);

            for (next_positions.slice()) |adj| {
                const dir = Direction.fromPositions(cur.pos, adj).?;
                const new_force = floodfill.dampening(map, cur.pos, dir, cur.force);

                const old_force = floodfill.contains(adj);

                // If the movement to this position has reduced force to 0, skip it.
                // Only process tiles where the old force is null (never seen before)
                // or we have hit an old tile but with more force.
                if (new_force > 0 and ((old_force orelse 0) < new_force)) {
                    // Record having seen this position.
                    const adj_hit_pos = HitPos{ .pos = adj, .force = new_force - 1 };
                    try floodfill.current.append(adj_hit_pos);
                    try floodfill.addHitPos(adj_hit_pos);
                }
            }
        }
    }

    /// Calculate the amount of force dampening based on the floodfill's blocked tile, shortwall, and
    /// full tile wall dampening options, if any.
    pub fn dampening(floodfill: *FloodFill, map: *const Map, pos: Pos, dir: Direction, force: i32) i32 {
        var amount: i32 = force;
        if (blocking.moveBlocked(map, pos, dir, .move)) |blocked| {
            if (blocked.blocked_tile) {
                if (floodfill.dampen_tile_blocked) |wall_dampening| {
                    amount = std.math.max(0, amount - wall_dampening);
                } else {
                    amount = 0;
                }
            }

            if (blocked.height == .short) {
                if (floodfill.dampen_short_wall) |wall_dampening| {
                    amount = std.math.max(0, amount - wall_dampening);
                } else {
                    amount = 0;
                }
            }

            if (blocked.height == .tall) {
                if (floodfill.dampen_tall_wall) |wall_dampening| {
                    amount = std.math.max(0, amount - wall_dampening);
                } else {
                    amount = 0;
                }
            }
        }

        return amount;
    }

    pub fn addHitPos(floodfill: *FloodFill, hit_pos: HitPos) !void {
        for (floodfill.flood.items) |*cur| {
            if (cur.pos.eql(hit_pos.pos)) {
                cur.force = hit_pos.force;
                return;
            }
        }
        try floodfill.flood.append(hit_pos);
    }

    pub fn contains(floodfill: *const FloodFill, pos: Pos) ?i32 {
        for (floodfill.flood.items) |cur| {
            if (cur.pos.eql(pos)) {
                return cur.force;
            }
        }
        return null;
    }
};

test "floodfill empty" {
    var allocator = std.testing.allocator;
    var map = try Map.fromDims(10, 10, allocator);
    defer map.deinit();

    const start = Pos.init(5, 5);
    var flood_fill = FloodFill.init(allocator);
    defer flood_fill.deinit();
    try flood_fill.fill(&map, start, 0);
    try std.testing.expectEqual(@as(usize, 1), flood_fill.flood.items.len);
    try std.testing.expect(start.eql(flood_fill.flood.items[0].pos));

    try flood_fill.fill(&map, start, 1);
    try std.testing.expectEqual(@as(usize, 9), flood_fill.flood.items.len);
}

test "floodfill some blocking" {
    var allocator = std.testing.allocator;
    var map = try Map.fromDims(10, 10, allocator);
    defer map.deinit();

    const start = Pos.init(5, 5);
    var flood_fill = FloodFill.init(allocator);
    defer flood_fill.deinit();
    var tile = Tile.init(Wall.empty(), Wall.empty(), Wall.short());
    map.set(Pos.init(5, 5), tile);
    map.set(Pos.init(5, 6), tile);
    map.set(Pos.init(5, 4), tile);

    try flood_fill.fill(&map, start, 1);
    try std.testing.expectEqual(@as(usize, 6), flood_fill.flood.items.len);
}

test "floodfill dampening" {
    var allocator = std.testing.allocator;
    var map = try Map.fromDims(10, 10, allocator);
    defer map.deinit();

    const start = Pos.init(5, 5);
    var flood_fill = FloodFill.init(allocator);
    defer flood_fill.deinit();
    var tile = Tile.shortLeftWall();
    map.set(Pos.init(5, 5), tile);
    map.set(Pos.init(5, 6), tile);
    map.set(Pos.init(5, 4), tile);
    //  Layout with s as the source of the sound:
    // . . . . .
    // . .|. . .
    // . .|s . .
    // . .|. . .
    // . . . . .
    //  Layout with x as tiles hit by sound with force 1
    // . . . . .
    // . .|s s .
    // . .|x s .
    // . .|s s .
    // . . . . .
    //  Layout with x as tiles hit by sound with force 2
    // . s s s s
    // . s|s s s
    // . s|x s s
    // . s|s s s
    // . s s s s

    flood_fill.dampen_short_wall = 1;

    try flood_fill.fill(&map, start, 1);
    try std.testing.expectEqual(@as(usize, 6), flood_fill.flood.items.len);

    try flood_fill.fill(&map, start, 2);
    try std.testing.expectEqual(@as(usize, 20), flood_fill.flood.items.len);
}

//test "floodfill opening" {
//    var allocator = std.testing.allocator;
//    var map = try Map.fromDims(10, 10, allocator);
//
//    const start = Pos.init(5, 5);
//    var flood_fill = FloodFill.init(allocator);
//    defer flood_fill.deinit();
//    map.getPtr(Pos.init(6, 3)).left.height = .short;
//    map.getPtr(Pos.init(5, 3)).left.height = .short;
//
//    map.getPtr(Pos.init(6, 4)).left.height = .short;
//    map.getPtr(Pos.init(5, 4)).left.height = .short;
//
//    map.getPtr(Pos.init(6, 5)).left.height = .short;
//    map.getPtr(Pos.init(5, 5)).left.height = .short;
//    map.getPtr(start).down.height = .short;
//
//    try flood_fill.fill(&map, start, 2);
//    try std.testing.expect(flood_fill.contains(start));
//    try std.testing.expect(flood_fill.contains(Pos.init(5, 4)));
//    try std.testing.expect(flood_fill.contains(Pos.init(5, 3)));
//
//    try flood_fill.fill(&map, start, 3);
//    try std.testing.expectEqual(@as(usize, 6), flood_fill.flood.items.len);
//}
