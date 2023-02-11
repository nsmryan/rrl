const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Map = @import("map.zig").Map;
const Tile = @import("tile.zig").Tile;
const Wall = Tile.Wall;

const math = @import("math");
const Pos = math.pos.Pos;

const utils = @import("utils");
const Array = utils.buffer.Array;

pub const FloodFill = struct {
    flood: ArrayList(Pos),
    current: ArrayList(Pos),

    pub fn init(allocator: Allocator) FloodFill {
        return FloodFill{
            .flood = ArrayList(Pos).init(allocator),
            .current = ArrayList(Pos).init(allocator),
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

        try floodfill.current.append(start);
        try floodfill.flood.append(start);

        while (floodfill.current.items.len > 0) {
            const cur = floodfill.current.pop();
            var reachable = try map.reachableNeighbors(cur);

            for (reachable.slice()) |adj| {
                if (start.distanceMaximum(adj) <= radius and !floodfill.contains(adj)) {
                    // record having seen this position.
                    try floodfill.current.append(adj);
                    try floodfill.flood.append(adj);
                }
            }
        }
    }

    pub fn contains(floodfill: *const FloodFill, pos: Pos) bool {
        for (floodfill.flood.items) |cur| {
            if (cur.eql(pos)) {
                return true;
            }
        }
        return false;
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
    try std.testing.expect(start.eql(flood_fill.flood.items[0]));

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
