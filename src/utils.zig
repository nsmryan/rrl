const std = @import("std");

pub const comp = @import("utils/comp.zig");
pub usingnamespace comp;

pub const line = @import("utils/line.zig");
pub usingnamespace line;

pub const math = @import("utils/math.zig");
pub usingnamespace math;

pub const rand = @import("utils/rand.zig");
pub usingnamespace rand;

pub const pos = @import("utils/pos.zig");
pub usingnamespace pos;

fn lessDistance(start: pos.Pos, first: pos.Pos, second: pos.Pos) bool {
    return line.Line.distance(start, first, true) < line.Line.distance(start, second, true);
}

pub fn sortByDistanceTo(start: pos.Pos, positions: []pos.Pos) void {
    std.sort.sort(pos.Pos, positions, start, lessDistance);
}

test "sort by distance" {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var positions = std.ArrayList(pos.Pos).init(allocator.allocator());

    try positions.append(pos.Pos.init(2, 1));
    try positions.append(pos.Pos.init(1, 1));
    try positions.append(pos.Pos.init(5, 10));
    try positions.append(pos.Pos.init(5, 5));

    sortByDistanceTo(pos.Pos.init(1, 1), positions.items);
    try std.testing.expectEqual(pos.Pos.init(1, 1), positions.items[0]);
    try std.testing.expectEqual(pos.Pos.init(2, 1), positions.items[1]);
    try std.testing.expectEqual(pos.Pos.init(5, 5), positions.items[2]);
    try std.testing.expectEqual(pos.Pos.init(5, 10), positions.items[3]);
}
