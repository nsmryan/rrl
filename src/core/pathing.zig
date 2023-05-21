const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const print = std.debug.print;

const utils = @import("utils");
const astar = utils.astar;

const math = @import("math");
const Pos = math.pos.Pos;
const Line = math.line.Line;
const Direction = math.direction.Direction;

const board = @import("board");
const blocking = board.blocking;
const Blocked = blocking.Blocked;
const BlockedType = blocking.BlockedType;

const Map = board.map.Map;
const tile = board.tile;

const Entities = @import("entities.zig").Entities;
const Level = @import("level.zig").Level;
const Reach = @import("movement.zig").Reach;

// multiplier used to scale costs up in astar, allowing small
// adjustments of costs even though they are integers.
pub const ASTAR_COST_MULTIPLIER: i32 = 100;

pub const CostFn = fn (*const Level, Pos, Pos) ?i32;

pub fn pathFindDistance(next_pos: Pos, end: Pos) usize {
    return @intCast(usize, Line.distance(next_pos, end, true) * ASTAR_COST_MULTIPLIER);
}

pub fn astarPath(level: *const Level, start: Pos, end: Pos, reach: Reach, cost_fn: ?*const CostFn, allocator: Allocator) !ArrayList(Pos) {
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

        try astarNeighbors(level, position, reach, &neighbors);
        for (neighbors.items) |near_pos| {
            var cost = @intCast(i32, pathFindDistance(near_pos, end));

            // NOTE(design) the cost function is used here as an addon to the distance to the target.
            // This seems more often useful then allowing the caller to decide the full cost.
            if (cost_fn) |cost_function| {
                if (cost_function(level, near_pos, start)) |addon_cost| {
                    cost += addon_cost * ASTAR_COST_MULTIPLIER;
                } else {
                    // If the cost function returns null this signals that we don't want to consider this position.
                    continue;
                }
            }
            try pairs.append(astar.WeighedPos.init(near_pos, cost));
        }

        result = try finder.step(pairs.items);
    }

    return result.done.path;
}

// Perform an AStar search from 'start' to 'end' and return the first move to take along this path,
// if a path exists.
pub fn astarNextPos(level: *const Level, start: Pos, end: Pos, cost_fn: ?fn (Pos, Pos, *const Level) i32) !?Pos {
    const next_positions = try astarPath(level, start, end, cost_fn);
    defer next_positions.deinit();

    if (next_positions.items.len > 0) {
        return next_positions.items[0];
    } else {
        return null;
    }
}

// Fill the given array list with the positions of tiles that can be reached with a single move
// from the given tile. The provided positions do not block when moving from 'start' to their location.
pub fn astarNeighbors(level: *const Level, pos: Pos, reach: Reach, neighbors: *ArrayList(Pos)) !void {
    neighbors.clearRetainingCapacity();

    const reachablePositions = try reach.reachables(pos);
    reachables: for (reachablePositions.constSlice()) |target_pos| {
        // If end position not on the map, move to next position.
        if (!level.map.isWithinBounds(target_pos)) {
            continue;
        }

        // Otherwise, draw a line from the start position to the reachable target position and
        // check whether there are obstacles when moving on each file.
        var line = Line.init(pos, target_pos, true);
        while (line.next()) |walk_pos| {
            // We check from starting tile to end whether movement towards the target is valid.
            // If we are at the target, there is no next tile to check validity for.
            if (walk_pos.eql(target_pos)) {
                break;
            }

            const dir = Direction.fromPositions(walk_pos, target_pos).?;
            const collision = level.checkCollision(walk_pos, dir);
            if (collision.hit()) {
                // If any intermediate position, including the last position, is blocked then just
                // continue searching with the next reachable position.
                continue :reachables;
            }
        }
        try neighbors.append(target_pos);
    }
}

test "path finding" {
    var allocator = std.testing.allocator;

    var map = try Map.fromDims(3, 3, allocator);
    var ents = Entities.init(allocator);
    var level = Level.init(map, ents);
    defer level.deinit();

    const start = Pos.init(0, 0);
    const end = Pos.init(2, 2);
    level.map.getPtr(Pos.init(1, 0)).center = tile.Tile.Wall.tall();
    level.map.getPtr(Pos.init(1, 1)).center = tile.Tile.Wall.tall();

    const reach = Reach.single(1);

    const path = try astarPath(&level, start, end, reach, null, allocator);
    defer path.deinit();

    try std.testing.expectEqual(Pos.init(0, 0), path.items[0]);
    try std.testing.expectEqual(Pos.init(0, 1), path.items[1]);
    try std.testing.expectEqual(Pos.init(1, 2), path.items[2]);
    try std.testing.expectEqual(Pos.init(2, 2), path.items[3]);
}
