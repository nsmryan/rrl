const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const math = @import("math");
const pos = math.pos;
const Pos = pos.Pos;
const Direction = math.direction.Direction;

const blocking = @import("blocking.zig");
const FovResult = blocking.FovResult;
const Blocked = blocking.Blocked;

const pathing = @import("pathing.zig");

const Map = @import("map.zig").Map;
const Height = @import("tile.zig").Tile.Height;

const shadowcasting = @import("shadowcasting.zig");

pub const FovError = error{OutOfMemory} || shadowcasting.Error;

pub const FovBlock = union(enum) {
    block,
    transparent,
    opaqu: usize,
    magnify: usize,
};

pub fn isInFovEdge(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, low: bool, allocator: Allocator) FovError!FovResult {
    if (try isInFov(map, start_pos, end_pos, radius + 1, low, allocator)) {
        if (start_pos.distanceMaximum(end_pos) == radius + 1) {
            return FovResult.edge;
        } else {
            return FovResult.inside;
        }
    } else {
        return FovResult.outside;
    }
}

pub fn isInFov(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, low: bool, allocator: Allocator) FovError!bool {
    if (start_pos.distanceMaximum(end_pos) > radius) {
        return false;
    }

    if (try isInFovShadowcast(map, start_pos, end_pos, allocator)) {
        // Make sure there is a clear path, but allow the player to
        // see walls (blocking position is the end_pos tile).
        var path_fov: ?Blocked = undefined;
        if (low) {
            path_fov = pathing.pathBlockedFovLow(map, start_pos, end_pos);
        } else {
            path_fov = pathing.pathBlockedFov(map, start_pos, end_pos);
        }

        if (path_fov) |blocked| {
            // If we get here, the position is in FOV but blocked.
            // The only blocked positions that are visible are at the end of the
            // path that are also block tiles (like a wall).
            return end_pos.eql(blocked.end_pos) and blocked.blocked_tile;
        } else {
            // Path not blocked, so in FoV.
            return true;
        }
    }

    return false;
}

// NOTE could this be duplicated for Fov and FovLow? The use of 'low' above helps but may not be perfect.
pub fn isBlocking(position: Pos, map: Map) bool {
    return !map.isWithinBounds(position) or blocking.BlockedType.fov.tileBlocks(map.get(position)) != Height.empty;
}

pub fn isInFovShadowcast(map: Map, start_pos: Pos, end_pos: Pos, allocator: Allocator) FovError!bool {
    // NOTE(perf) add back in with fov_cache
    //if (self.fov_cache.borrow_mut().get(&start_pos)) |visible| {
    //
    //    return visible.contains(&end_pos);
    //}

    //// NOTE(perf) this should be correct- shadowcasting is symmetrical, so
    //// we either need a precomputed start-to-end or end-to-start
    //// calculation, but not both.
    //if (self.fov_cache.borrow_mut().get(&end_pos)) |visible| {
    //    return visible.contains(&start_pos);
    //}

    // NOTE(perf) this pre-allocation speeds up FOV significantly
    var visible_positions: ArrayList(Pos) = try ArrayList(Pos).initCapacity(allocator, 120);
    defer visible_positions.deinit();

    try shadowcasting.computeFov(start_pos, map, &visible_positions, isBlocking);

    var in_fov = false;
    for (visible_positions.items) |position| {
        if (position.eql(end_pos)) {
            in_fov = true;
            break;
        }
    }

    // NOTE(perf) add back in with fov_cache
    //self.fov_cache.borrow_mut().insert(start_pos, visible_positions);

    return in_fov;
}

pub fn isInFovDirection(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, dir: Direction, low: bool, allocator: Allocator) FovError!bool {
    if (start_pos.eql(end_pos)) {
        return true;
    } else if (try isInFov(map, start_pos, end_pos, radius, low, allocator)) {
        return math.visibleInDirection(start_pos, end_pos, dir);
    } else {
        return false;
    }
}
