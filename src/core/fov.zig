const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const DynamicBitSet = std.DynamicBitSet;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const Dims = math.utils.Dims;
const Line = math.line.Line;

const board = @import("board");
const FovResult = board.blocking.FovResult;
const Blocked = board.blocking.Blocked;
const blocking = board.blocking;

const pathing = board.pathing;
const BlockedType = board.blocking.BlockedType;

const Map = board.map.Map;
const Height = board.tile.Tile.Height;

const shadowcasting = board.shadowcasting;
const Pov = shadowcasting.Pov;

const utils = @import("utils");
const comp = utils.comp;
const Id = comp.Id;

const entities = @import("entities.zig");
const Type = entities.Type;

const Level = @import("level.zig").Level;

pub const FovError = error{OutOfMemory} || shadowcasting.Error;

pub const FovBlock = union(enum) {
    block,
    transparent,
    opaqu: usize,
    magnify: usize,
};

pub const ViewHeight = enum {
    low,
    high,
};

pub const View = struct {
    map: Pov,
    low: Pov,
    high: Pov,
    explored: DynamicBitSet,

    pub fn init(dims: Dims, allocator: Allocator) !View {
        const numTiles = dims.numTiles();
        return View{
            .map = try Pov.init(dims, allocator),
            .low = try Pov.init(dims, allocator),
            .high = try Pov.init(dims, allocator),
            .explored = try DynamicBitSet.initEmpty(allocator, numTiles),
        };
    }

    pub fn isExplored(view: *const View, pos: Pos) bool {
        return view.explored.isSet(view.map.dims.toIndex(pos));
    }

    pub fn deinit(view: *View) void {
        view.map.deinit();
        view.low.deinit();
        view.high.deinit();
        view.explored.deinit();
    }

    pub fn resize(view: *View, dims: Dims) !void {
        try view.map.resize(dims);
        try view.low.resize(dims);
        try view.high.resize(dims);
        try view.explored.resize(dims.numTiles(), false);
    }
};

//pub fn isInFovEdge(map: Map, start_pos: Pos, end_pos: Pos, radius: i32, view_height: ViewHeight) FovError!FovResult {
//    if (try isInFov(map, start_pos, end_pos, radius + 1, view_height)) {
//        if (start_pos.distanceMaximum(end_pos) == radius + 1) {
//            return FovResult.edge;
//        } else {
//            return FovResult.inside;
//        }
//    } else {
//        return FovResult.outside;
//    }
//}

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
        const dir = Direction.fromPositions(last_pos, target_pos);
        const blocked = blocking.moveBlocked(&map, last_pos, dir.?, blocked_type);
        if (blocked != null) {
            return blocked;
        }
        last_pos = target_pos;
    }

    return null;
}

pub fn isInFov(map: Map, start_pos: Pos, end_pos: Pos, view_height: ViewHeight) FovError!bool {
    // Make sure there is a clear path, but include walls (blocking position is the end_pos tile).
    var path_fov: ?Blocked = switch (view_height) {
        .low => pathBlockedFovLow(map, start_pos, end_pos),
        .high => pathBlockedFov(map, start_pos, end_pos),
    };

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

// NOTE is this even useful? it would be for one-off FoV calculations.
//pub fn isInFovShadowcast(map: Map, start_pos: Pos, end_pos: Pos, allocator: Allocator) FovError!bool {
//    var pov: Pov = Pov.init(map.dims(), allocator);
//    defer pov.deinit();
//
//    try shadowcasting.computeFov(start_pos, map, &pov);
//    return pos.isVisible(end_pos);
//}

pub fn isInFovDirection(map: Map, start_pos: Pos, end_pos: Pos, dir: Direction, view_height: ViewHeight) FovError!bool {
    if (math.visibleInDirection(start_pos, end_pos, dir)) {
        return try isInFov(map, start_pos, end_pos, view_height);
    } else {
        return false;
    }
}

pub fn fovCheck(level: *Level, id: Id, check_pos: Pos, view_height: ViewHeight) FovError!bool {
    // Do a quick map bounds check to short-circuit this case.
    if (!level.map.isWithinBounds(check_pos)) {
        return false;
    }

    const entity_pos = level.entities.pos.get(id);

    // Add in the result of magnification effects.
    // NOTE(implement) magnification
    //view_distance += try level.fovMagnification(id, check_pos, view_height, allocator);

    var is_in_fov: bool = false;

    // The player and the other entities have slightly different FoV checks.
    // The other entities have directional FoV which is layered on the base FoV algorithm.
    if (level.entities.typ.get(id) == Type.player) {
        is_in_fov = try isInFov(level.map, entity_pos, check_pos, view_height);
        // NOTE(implement) lanterns
        // If we can't see the tile, check for a latern that illuminates it, allowing
        // us to see it anyway. Ignore tiles that are blocked for sight anyway.
        //if fov_result != FovResult::Inside and !level.map[check_pos].block_sight {
        //fov_result = level.check_illumination(id, fov_result, check_pos, ILLUMINATE_FOV_RADIUS, view_height);
    } else {
        if (level.entities.facing.getOrNull(id)) |dir| {
            is_in_fov = try isInFovDirection(level.map, entity_pos, check_pos, dir, view_height);
        } else {
            std.debug.panic("tried to perform fov check on entity without facing", .{});
        }
    }

    // If the position is within Fov then apply modifiers from fog, etc.
    // NOTE(implement) fog reduction
    //var fog_reduction: i32 = 0;
    //if (fov_result != FovResult.outside) {
    //    // NOTE(implement) fov reduction from fog
    //    //fog_reduction = level.fovReduction(id, check_pos, view_distance);
    //    // This subtraction is safe due to checks within fov_reduction.
    //    view_distance -= fog_reduction;

    //    const pos_dist = entity_pos.distanceMaximum(check_pos);
    //    if (pos_dist == view_distance + 1) {
    //        fov_result = FovResult.edge;
    //    } else if (pos_dist <= view_distance) {
    //        fov_result = FovResult.inside;
    //    } else {
    //        fov_result = FovResult.outside;
    //    }
    //}

    // NOTE(implement) illumination
    //if (level.entities.typ.get(id) == Type.player) {
    //    // If we can't see the tile, check for a latern that illuminates it, allowing
    //    // us to see it anyway. Ignore tiles that are blocked for sight anyway.
    //    if (fov_result != FovResult.inside and !level.map.get(check_pos).block_sight) {
    //        // First, check that there is no FoV blocker between the player
    //        // and the check position. If there is, we return the current answer.
    //        // Otherwise we check for illuminators.
    //        var to_line = Line.init(entity_pos, check_pos, false);
    //        while (to_line.next()) |to_pos| {
    //            var from_line = Line.init(check_pos, entity_pos, false);
    //            while (from_line.next()) |from_pos| {
    //                // If the lines overlap, check for FoV modifying entities.
    //                if (to_pos.eql(from_pos)) {
    //                    for (level.entities.fov_block.ids.item) |entity_id| {
    //                        const fov_block = level.entities.fov_block.get(entity_id);
    //                        if (fov_block == .opaqu or fov_block == .block) {
    //                            // We just return fov_result here as the remaining modifications
    //                            // only apply illumination which does not pierce the fog.
    //                            return fov_result;
    //                        }
    //                    }
    //                }
    //            }
    //        }

    //        fov_result = level.checkIllumination(id, fov_result, check_pos, fog_reduction, crouching, allocator);
    //    }
    //}

    return is_in_fov;
}

// NOTE(implement) magnification
//fn fovMagnification(level: *Level, id: Id, check_pos: Pos, crouching: bool, allocator: Allocator) FovError!i32 {
//    const entity_pos = level.entities.pos.get(id);
//    var magnification: i32 = 0;

//    for (level.entities.fov_block.ids.items) |fov_block_id| {
//        const fov_block: ?FovBlock = level.entities.fov_block.get(fov_block_id);
//        var to_line = Line.init(entity_pos, check_pos, false);
//        while (to_line.next()) |to_pos| {
//            // fov_check_result is an Option to avoid computing this fovCheck unless there
//            // is actually a magnifier in line with the entity's FoV.
//            var fov_check_result: ?bool = null;

//            var from_line = Line.init(check_pos, entity_pos, false);
//            while (from_line.next()) |from_pos| {
//                // If the lines overlap, check for magnifiers
//                if (to_pos.eql(from_pos)) {
//                    if (level.entities.pos.get(fov_block_id).eql(to_pos)) {
//                        if (fov_block) |fov_block_value| {
//                            switch (fov_block_value) {
//                                FovBlock.magnify => {
//                                    const amount = fov_block_value.magnify;
//                                    if (fov_check_result == null) {
//                                        fov_check_result = try level.fovCheck(id, to_pos, crouching, allocator) == FovResult.inside;
//                                    }

//                                    if (fov_check_result == true) {
//                                        magnification += @intCast(i32, amount);
//                                    }
//                                },
//                                else => {},
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }

//    return magnification;
//}

// NOTE(implement) fov reduction through fog
//fn fovReduction(level: *Level, id: Id, check_pos: Pos, view_distance: i32) i32 {
//    var reduction: i32 = 0;

//    const entity_pos = level.entities.pos.get(id);

//    // Search along a line from the entity, to the given position,
//    // and search back from the given position to the entity, looking
//    // for matching positions.
//    var to_line = Line.init(entity_pos, check_pos, false);
//    while (to_line.next()) |to_pos| {
//        var from_line = Line.init(check_pos, entity_pos, false);
//        for (from_line.next()) |from_pos| {
//            // If the lines overlap, check for FoV modifying entities.
//            if (to_pos.eql(from_pos)) {
//                for (level.entities.fov_block.ids.item) |entity_id| {
//                    const fov_block = level.entities.fov_block.get(entity_id);
//                    if (level.entities.pos.get(id).eql(to_pos)) {
//                        switch (fov_block) {
//                            .block => {
//                                // Blocking entities completely block LoS
//                                return 0;
//                            },

//                            .transparent => {
//                                // Transparent FovBlockers have no effect.
//                            },

//                            .opaqu => |amount| {
//                                // If an entity makes the tile completely
//                                // outside of the FoV, we can just return
//                                // immediately.
//                                if (@as(i32, amount) + reduction > view_distance) {
//                                    return view_distance;
//                                }
//                                reduction += @as(i32, amount);
//                            },

//                            .magnify => {
//                                // magnification is handled before FoV above.
//                            },
//                        }
//                    }
//                }
//            }
//        }
//    }

//    return reduction;
//}

//pub fn checkIllumination(level: *Level, id: Id, init_fov_result: FovResult, check_pos: Pos, reduction: i32, view_height: ViewHeight) FovError!FovResult {
//    var fov_result = init_fov_result;
//    const entity_pos = level.entities.pos.get(id);

//    if (reduction > ILLUMINATE_FOV_RADIUS) {
//        return fov_result;
//    }
//    const illuminate_fov_radius = ILLUMINATE_FOV_RADIUS - reduction;

//    // check for illumination that might make this tile visible.
//    for (level.entities.illuminate.ids.items) |entity_id| {
//        const illuminate_radius = level.entities.illuminate.get(entity_id);

//        const illuminator_on_map = level.map.isWithinBounds(level.entities.pos.get(entity_id));

//        if (illuminate_radius != 0 and illuminator_on_map and !level.entities.needs_removal.get(entity_id)) {
//            const illuminate_pos = level.entities.pos.get(entity_id);

//            const pos_near_illuminator = try fov.isInFov(level.map, illuminate_pos, check_pos, @intCast(i32, illuminate_radius), view_height);
//            if (pos_near_illuminator) {
//                // Check that the position is within the radius visible through
//                // illumination. This prevents seeing illuminated tiles that are just
//                // too far for the player to reasonably see.
//                if (try fov.isInFov(level.map, entity_pos, check_pos, illuminate_fov_radius, view_height)) {
//                    const max_axis_dist = illuminate_pos.distanceMaximum(check_pos);
//                    if (max_axis_dist < illuminate_radius) {
//                        // The position is fully within the illumination radius.
//                        fov_result = fov_result.combine(FovResult.inside);
//                    } else if (max_axis_dist == illuminate_radius) {
//                        // The position is just at the edge of the illumation radius.
//                        fov_result = fov_result.combine(FovResult.edge);
//                    }
//                    // Otherwise return the original result, Edge or Outside.
//                }
//            }
//        }
//    }

//    return fov_result;
//}

