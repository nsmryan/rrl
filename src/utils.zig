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

pub const direction = @import("utils/direction.zig");
pub usingnamespace direction;

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

pub fn visibleInDirection(start: pos.Pos, end: pos.Pos, dir: direction.Direction) bool {
    const pos_diff = end.sub(start);
    const view_dir = dir.offsetPos(start, 1);
    return view_dir.dot(pos_diff) >= 0;
}

test "test visible in direction" {
    const start_pos = pos.Pos.init(0, 0);

    const dirs = direction.Direction.directions();
    for (dirs) |dir| {
        var index: usize = 0;
        var current_dir = dir;
        while (index < dirs.len) : (index += 1) {
            const end_pos = current_dir.offsetPos(start_pos, 1);

            const turn_amount = try std.math.absInt(dir.turnAmount(current_dir));
            if (turn_amount >= 3) {
                try std.testing.expect(!visibleInDirection(start_pos, end_pos, dir));
            } else {
                try std.testing.expect(visibleInDirection(start_pos, end_pos, dir));
            }

            current_dir = current_dir.clockwise();
        }
    }
}

pub fn randomOffset(rng: std.rand.Random, radius: i32) pos.Pos {
    return pos.Pos.init(rng.intRangeAtMost(i32, -radius, radius), rng.intRangeAtMost(i32, -radius, radius));
}

pub fn randPosInRadius(position: pos.Pos, radius: i32, rng: std.rand.Random) pos.Pos {
    const offset = pos.Pos.init(rng.intRangeAtMost(i32, -radius, radius), rng.intRangeAtMost(i32, -radius, radius));
    return position.add(offset);
}

test "utils test set" {
    _ = @import("utils/comp.zig");
    _ = @import("utils/line.zig");
    _ = @import("utils/math.zig");
    _ = @import("utils/rand.zig");
    _ = @import("utils/pos.zig");
    _ = @import("utils/direction.zig");
    _ = @import("utils/astar.zig");
}
