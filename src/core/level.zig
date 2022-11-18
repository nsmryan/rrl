const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const board = @import("board");
const Map = board.map.Map;
const blocking = board.blocking;
const BlockedType = board.blocking.BlockedType;
const FovResult = board.blocking.FovResult;
const fov = board.fov;
const FovBlock = fov.FovBlock;
const FovError = fov.FovError;
const Tile = board.tile.Tile;

const utils = @import("utils");
const Id = utils.comp.Id;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const Line = math.line.Line;

const movement = @import("movement.zig");
const Collision = movement.Collision;
const HitWall = movement.HitWall;

const entities = @import("entities.zig");
const Entities = entities.Entities;
const Type = entities.Type;
const Stance = entities.Stance;

pub const ILLUMINATE_FOV_RADIUS: i32 = 1000;

pub const Level = struct {
    map: Map,
    entities: Entities,

    pub fn init(map: Map, ents: Entities) Level {
        return Level{ .map = map, .entities = ents };
    }

    pub fn deinit(level: *Level) void {
        level.map.deinit();
        level.entities.deinit();
    }

    pub fn empty(allocator: Allocator) Level {
        return Level.init(Map.empty(allocator), Entities.init(allocator));
    }

    pub fn fromDims(width: i32, height: i32, allocator: Allocator) !Level {
        return Level.init(try Map.fromDims(width, height, allocator), Entities.init(allocator));
    }

    pub fn checkCollision(level: *Level, pos: Pos, dir: Direction) Collision {
        var collision: Collision = Collision.init(pos, dir);
        if (blocking.moveBlocked(&level.map, pos, dir, BlockedType.move)) |blocked| {
            collision.wall = HitWall.init(blocked.height, blocked.blocked_tile);
        }

        collision.entity = level.blockingEntityAt(dir.move(pos));

        return collision;
    }

    pub fn blockingEntityAt(level: *Level, pos: Pos) bool {
        for (level.entities.ids.items) |id| {
            if (level.entities.pos.get(id)) |entity_pos| {
                if (entity_pos.eql(pos) and level.entities.blocking.has(id)) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn entityInFov(level: *Level, id: Id, other: Id, allocator: Allocator) FovError!FovResult {
        const stance = level.entities.stance.get(id).?;
        const other_stance = level.entities.stance.get(other) orelse Stance.standing;
        const crouching = stance == Stance.crouching or other_stance == Stance.crouching;

        const other_pos = level.entities.pos.get(other).?;
        return try level.fovCheck(id, other_pos, crouching, allocator);
    }

    pub fn posInFov(level: *Level, id: Id, other_pos: Pos, allocator: Allocator) FovError!FovResult {
        const crouching = level.entities.stance.get(id).? == Stance.crouching;
        return try level.fovCheck(id, other_pos, crouching, allocator);
    }

    pub fn posInsideFov(level: *Level, id: Id, other_pos: Pos, allocator: Allocator) FovError!bool {
        return try level.posInFov(id, other_pos, allocator) == FovResult.inside;
    }

    // NOTE(implement) magnification
    fn fovMagnification(level: *Level, id: Id, check_pos: Pos, crouching: bool, allocator: Allocator) FovError!i32 {
        const entity_pos = level.entities.pos.get(id).?;
        var magnification: i32 = 0;

        for (level.entities.fov_block.ids.items) |fov_block_id| {
            const fov_block: ?FovBlock = level.entities.fov_block.get(fov_block_id);
            var to_line = Line.init(entity_pos, check_pos, false);
            while (to_line.next()) |to_pos| {
                // fov_check_result is an Option to avoid computing this fovCheck unless there
                // is actually a magnifier in line with the entity's FoV.
                var fov_check_result: ?bool = null;

                var from_line = Line.init(check_pos, entity_pos, false);
                while (from_line.next()) |from_pos| {
                    // If the lines overlap, check for magnifiers
                    if (to_pos.eql(from_pos)) {
                        if (level.entities.pos.get(fov_block_id).?.eql(to_pos)) {
                            if (fov_block) |fov_block_value| {
                                switch (fov_block_value) {
                                    FovBlock.magnify => {
                                        const amount = fov_block_value.magnify;
                                        if (fov_check_result == null) {
                                            fov_check_result = try level.fovCheck(id, to_pos, crouching, allocator) == FovResult.inside;
                                        }

                                        if (fov_check_result == true) {
                                            magnification += @intCast(i32, amount);
                                        }
                                    },
                                    else => {},
                                }
                            }
                        }
                    }
                }
            }
        }

        return magnification;
    }

    // NOTE(implement) fov reduction through fog
    fn fovReduction(level: *Level, id: Id, check_pos: Pos, view_distance: i32) i32 {
        var reduction: i32 = 0;

        const entity_pos = level.entities.pos.get(id).?;

        // Search along a line from the entity, to the given position,
        // and search back from the given position to the entity, looking
        // for matching positions.
        var to_line = Line.init(entity_pos, check_pos, false);
        while (to_line.next()) |to_pos| {
            var from_line = Line.init(check_pos, entity_pos, false);
            for (from_line.next()) |from_pos| {
                // If the lines overlap, check for FoV modifying entities.
                if (to_pos.eql(from_pos)) {
                    for (level.entities.fov_block.ids.item) |entity_id| {
                        const fov_block = level.entities.fov_block.get(entity_id).?;
                        if (level.entities.pos.get(id).?.eql(to_pos)) {
                            switch (fov_block) {
                                .block => {
                                    // Blocking entities completely block LoS
                                    return 0;
                                },

                                .transparent => {
                                    // Transparent FovBlockers have no effect.
                                },

                                .opaqu => |amount| {
                                    // If an entity makes the tile completely
                                    // outside of the FoV, we can just return
                                    // immediately.
                                    if (@as(i32, amount) + reduction > view_distance) {
                                        return view_distance;
                                    }
                                    reduction += @as(i32, amount);
                                },

                                .magnify => {
                                    // magnification is handled before FoV above.
                                },
                            }
                        }
                    }
                }
            }
        }

        return reduction;
    }

    pub fn fovCheck(level: *Level, id: Id, check_pos: Pos, crouching: bool, allocator: Allocator) FovError!FovResult {
        if (!level.map.isWithinBounds(check_pos)) {
            return FovResult.outside;
        }

        const entity_pos = level.entities.pos.get(id).?;
        var view_distance: i32 = level.entities.fov_radius.get(id).?;

        // Add in the result of magnification effects.
        // NOTE(implement) magnification
        //view_distance += try level.fovMagnification(id, check_pos, crouching, allocator);

        var fov_result: FovResult = undefined;

        // The player and the other entities have slightly different FoV checks.
        // The other entities have directional FoV which is layered on the base FoV algorithm.
        if (level.entities.typ.get(id).? == Type.player) {
            fov_result = try fov.isInFovEdge(level.map, entity_pos, check_pos, view_distance, crouching, allocator);
            // If we can't see the tile, check for a latern that illuminates it, allowing
            // us to see it anyway. Ignore tiles that are blocked for sight anyway.
            //if fov_result != FovResult::Inside and !level.map[check_pos].block_sight {
            //fov_result = level.check_illumination(id, fov_result, check_pos, ILLUMINATE_FOV_RADIUS, crouching);
        } else {
            if (level.entities.facing.get(id)) |dir| {
                if (try fov.isInFovDirection(level.map, entity_pos, check_pos, view_distance, dir, crouching, allocator)) {
                    fov_result = FovResult.inside;
                } else {
                    fov_result = FovResult.outside;
                }
            } else {
                std.debug.panic("tried to perform isInFov_on entity without facing", .{});
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
        //if (level.entities.typ.get(id).? == Type.player) {
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
        //                        const fov_block = level.entities.fov_block.get(entity_id).?;
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

        return fov_result;
    }

    pub fn checkIllumination(level: *Level, id: Id, init_fov_result: FovResult, check_pos: Pos, reduction: i32, crouching: bool, allocator: Allocator) FovError!FovResult {
        var fov_result = init_fov_result;
        const entity_pos = level.entities.pos.get(id).?;

        if (reduction > ILLUMINATE_FOV_RADIUS) {
            return fov_result;
        }
        const illuminate_fov_radius = ILLUMINATE_FOV_RADIUS - reduction;

        // check for illumination that might make this tile visible.
        for (level.entities.illuminate.ids.items) |entity_id| {
            const illuminate_radius = level.entities.illuminate.get(entity_id).?;

            const illuminator_on_map = level.map.isWithinBounds(level.entities.pos.get(entity_id).?);

            if (illuminate_radius != 0 and illuminator_on_map and !level.entities.needs_removal.get(entity_id).?) {
                const illuminate_pos = level.entities.pos.get(entity_id).?;

                const pos_near_illuminator = try fov.isInFov(level.map, illuminate_pos, check_pos, @intCast(i32, illuminate_radius), crouching, allocator);
                if (pos_near_illuminator) {
                    // Check that the position is within the radius visible through
                    // illumination. This prevents seeing illuminated tiles that are just
                    // too far for the player to reasonably see.
                    if (try fov.isInFov(level.map, entity_pos, check_pos, illuminate_fov_radius, crouching, allocator)) {
                        const max_axis_dist = illuminate_pos.distanceMaximum(check_pos);
                        if (max_axis_dist < illuminate_radius) {
                            // The position is fully within the illumination radius.
                            fov_result = fov_result.combine(FovResult.inside);
                        } else if (max_axis_dist == illuminate_radius) {
                            // The position is just at the edge of the illumation radius.
                            fov_result = fov_result.combine(FovResult.edge);
                        }
                        // Otherwise return the original result, Edge or Outside.
                    }
                }
            }
        }

        return fov_result;
    }

    pub fn fovRadius(level: *Level, id: Id) i32 {
        if (level.entities.fov_radius.get(id) == null) {
            std.log.debug("{} {} {}", .{ id, level.entities.name.get(id).?, level.entities.typ.get(id).? });
        }
        var radius: i32 = level.entities.fov_radius.get(id).?;

        // NOTE(implement) extra fov radius when available
        //if (level.entities.status.get(id)) |status| {
        //    radius += @as(i32, status.extra_fov);
        //}

        return radius;
    }
};
