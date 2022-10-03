const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const pos = utils.pos;
const Pos = pos.Pos;
const Direction = utils.direction.Direction;

const blocking = @import("blocking.zig");
const FovResult = blocking.FovResult;

const pathing = @import("pathing.zig");

const Map = @import("map.zig").Map;

const shadowcasting = @import("shadowcasting.zig").Map;

pub fn isInFovEdge(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, low: bool, allocator: Allocator) FovResult {
    if (map.isInFov(start_pos, end_pos, radius + 1, low, allocator)) {
        if (pos.distanceMaximum(start_pos, end_pos) == radius + 1) {
            return FovResult.edge;
        } else {
            return FovResult.inside;
        }
    } else {
        return FovResult.outside;
    }
}

pub fn isInFov(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, low: bool, allocator: Allocator) bool {
    if (pos.distanceMaximum(start_pos, end_pos) > radius) {
        return false;
    }

    if (isInFovShadowcast(map, start_pos, end_pos, allocator)) {
        // Make sure there is a clear path, but allow the player to
        // see walls (blocking position is the end_pos tile).
        var path_fov = undefined;
        if (low) {
            path_fov = pathing.pathBlockedFovLow(map, start_pos, end_pos, allocator);
        } else {
            path_fov = pathing.pathBlockedFov(map, start_pos, end_pos, allocator);
        }

        if (path_fov) |blocked| {
            // If we get here, the position is in FOV but blocked.
            // The only blocked positions that are visible are at the end of the
            // path that are also block tiles (like a wall).
            return end_pos == blocked.end_pos and blocked.blocked_tile;
        } else {
            // Path not blocked, so in FoV.
            return true;
        }
    }

    return false;
}

// NOTE could this be duplicated for Fov and FovLow? The use of 'low' above helps but may not be perfect.
pub fn isBlocking(position: Pos, map: Map) bool {
    return map.is_within_bounds(pos) and blocking.BlockedType.fov.tileBlocks(map.get(position));
}

pub fn isInFovShadowcast(map: Map, start_pos: Pos, end_pos: Pos, allocator: Allocator) bool {
    // NOTE(perf) add back in with fov_cache
    //if (self.fov_cache.borrow_mut().get(&start_pos)) |visible| {
    //    return visible.contains(&end_pos);
    //}

    //// NOTE(perf) this should be correct- shadowcasting is symmetrical, so
    //// we either need a precomputed start-to-end or end-to-start
    //// calculation, but not both.
    //if (self.fov_cache.borrow_mut().get(&end_pos)) |visible| {
    //    return visible.contains(&start_pos);
    //}

    // NOTE(perf) this pre-allocation speeds up FOV significantly
    var visible_positions = ArrayList(Pos).init_capacity(allocator, 120);

    shadowcasting.computeFov(start_pos, map, &visible_positions, isBlocking);

    var in_fov = false;
    for (visible_positions.items) |position| {
        if (position == end_pos) {
            in_fov = true;
            break;
        }
    }

    // NOTE(perf) add back in with fov_cache
    //self.fov_cache.borrow_mut().insert(start_pos, visible_positions);

    return in_fov;
}

pub fn isInFovDirection(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, dir: Direction, low: bool, allocator: Allocator) bool {
    if (start_pos == end_pos) {
        return true;
    } else if (isInFov(map, start_pos, end_pos, radius, low, allocator)) {
        return utils.visibleInDirection(start_pos, end_pos, dir);
    } else {
        return false;
    }
}
