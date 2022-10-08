const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const utils = @import("utils");
const astar = utils.astar;

const math = @import("math");
const Pos = math.pos.Pos;
const Line = math.line.Line;

const blocking = @import("blocking.zig");
const Blocked = blocking.Blocked;
const BlockedType = blocking.BlockedType;

const Map = @import("map.zig").Map;
const tile = @import("tile.zig");

// multiplier used to scale costs up in astar, allowing small
// adjustments of costs even though they are integers.
pub const ASTAR_COST_MULTIPLIER: i32 = 100;

pub fn pathBlockedFov(map: Map, start_pos: Pos, end_pos: Pos) ?Blocked {
    return pathBlocked(map, start_pos, end_pos, BlockedType.fov);
}

pub fn pathBlockedFovLow(map: Map, start_pos: Pos, end_pos: Pos) ?Blocked {
    return pathBlocked(map, start_pos, end_pos, BlockedType.fovLow);
}

pub fn pathBlockedMove(map: Map, start_pos: Pos, end_pos: Pos) ?Blocked {
    return pathBlocked(map, start_pos, end_pos, BlockedType.move);
}

pub fn pathBlocked(map: Map, start_pos: Pos, end_pos: Pos, blocked_type: BlockedType) ?Blocked {
    var line = Line.init(start_pos, end_pos, false);

    var last_pos = start_pos;
    while (line.next()) |target_pos| {
        const blocked = blocking.moveBlocked(map, last_pos, target_pos, blocked_type);
        if (blocked != null) {
            return blocked;
        }
        last_pos = target_pos;
    }

    return null;
}

pub fn pathFindDistance(next_pos: Pos, end: Pos) usize {
    return @intCast(usize, Line.distance(next_pos, end, true) * ASTAR_COST_MULTIPLIER);
}

pub fn astarPath(map: Map, start: Pos, end: Pos, max_dist: ?i32, cost_fn: ?fn (Pos, Pos, Map) i32, allocator: Allocator) !ArrayList(Pos) {
    const PathFinder = astar.Astar(pathFindDistance);

    var finder = PathFinder.init(start, allocator);
    defer finder.deinit();

    var result = try finder.pathFind(start, end);

    var neighbors = ArrayList(Pos).init(allocator);
    defer neighbors.deinit();

    var pairs = ArrayList(astar.WeighedPos).init(allocator);
    defer pairs.deinit();

    while (result == .neighbors) {
        neighbors.clearRetainingCapacity();
        pairs.clearRetainingCapacity();

        const position = result.neighbors;

        try astarNeighbors(map, start, position, max_dist, &neighbors);
        for (neighbors.items) |near_pos| {
            if (cost_fn) |cost| {
                try pairs.append(astar.WeighedPos.init(near_pos, cost(near_pos, start, map) * ASTAR_COST_MULTIPLIER));
            } else {
                try pairs.append(astar.WeighedPos.init(near_pos, @intCast(i32, pathFindDistance(near_pos, end))));
            }
        }

        result = try finder.step(pairs.items);
    }

    return result.done.path;
}

// Perform an AStar search from 'start' to 'end' and return the first move to take along this path,
// if a path exists.
pub fn astarNextPos(map: Map, start: Pos, end: Pos, max_dist: ?i32, cost_fn: ?fn (Pos, Pos, Map) i32) !?Pos {
    const next_positions = try astarPath(map, start, end, max_dist, cost_fn);

    if (next_positions.items.len > 0) {
        return next_positions.items[0];
    } else {
        return null;
    }
}

// Fill the given array list with the positions of tiles that can be reached with a single move
// from the given tile. The provided positions do not block when moving from 'start' to their location.
pub fn astarNeighbors(map: Map, start: Pos, pos: Pos, max_dist: ?i32, neighbors: *ArrayList(Pos)) !void {
    neighbors.clearRetainingCapacity();

    if (max_dist != null and Line.distance(start, pos, true) > max_dist.?) {
        return;
    }

    try blocking.reachableNeighbors(&map, pos, BlockedType.move, neighbors);
}

test "path finding" {
    var allocator = std.testing.allocator;

    var map = try Map.fromDims(3, 3, allocator);
    defer map.deinit(allocator);

    const start = Pos.init(0, 0);
    const end = Pos.init(2, 2);
    map.getPtr(Pos.init(1, 0)).center = tile.Tile.Wall.tall();
    map.getPtr(Pos.init(1, 1)).center = tile.Tile.Wall.tall();

    const path = try astarPath(map, start, end, null, null, allocator);
    defer path.deinit();

    try std.testing.expectEqual(Pos.init(0, 0), path.items[0]);
    try std.testing.expectEqual(Pos.init(0, 1), path.items[1]);
    try std.testing.expectEqual(Pos.init(1, 2), path.items[2]);
    try std.testing.expectEqual(Pos.init(2, 2), path.items[3]);
}