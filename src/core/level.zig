const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const board = @import("board");
const Map = board.map.Map;
const blocking = board.blocking;
const BlockedType = board.blocking.BlockedType;
const FovResult = board.blocking.FovResult;
const Tile = board.tile.Tile;
const shadowcasting = board.shadowcasting;

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

const prof = @import("prof");

const fov = @import("fov.zig");
const ViewHeight = fov.ViewHeight;
const FovBlock = fov.FovBlock;
const FovError = fov.FovError;

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

    pub fn checkCollision(level: *const Level, pos: Pos, dir: Direction) Collision {
        var collision: Collision = Collision.init(pos, dir);
        if (blocking.moveBlocked(&level.map, pos, dir, BlockedType.move)) |blocked| {
            collision.wall = HitWall.init(blocked.height, blocked.blocked_tile);
        }

        collision.entity = level.blockingEntityAt(dir.move(pos));

        return collision;
    }

    pub fn blockingEntityAt(level: *const Level, pos: Pos) bool {
        for (level.entities.ids.items) |id| {
            if (level.entities.pos.getOrNull(id)) |entity_pos| {
                if (entity_pos.eql(pos) and level.entities.blocking.has(id)) {
                    return level.entities.blocking.get(id);
                }
            }
        }
        return false;
    }

    pub fn itemAtPos(level: *const Level, pos: Pos) ?Id {
        for (level.entities.ids.items) |id| {
            if (level.entities.pos.getOrNull(id)) |entity_pos| {
                if (entity_pos.eql(pos) and level.entities.typ.get(id) == .item) {
                    return id;
                }
            }
        }
        return null;
    }

    pub fn updateAllFov(level: *Level) !void {
        for (level.entities.view.ids.items) |id| {
            try level.updateFov(id);
        }
    }

    pub fn updateFov(level: *Level, id: Id) !void {
        prof.scope("fov");
        defer prof.end();

        // Only calculate FoV for the player and enemies.
        if (!(level.entities.typ.get(id) == .player or level.entities.typ.get(id) == .enemy)) {
            return;
        }

        const start_pos = level.entities.pos.get(id);

        var view_ptr = level.entities.view.getPtr(id);
        try view_ptr.resize(level.map.dims());

        view_ptr.low.clear();
        view_ptr.high.clear();
        // NOTE 'map' is cleared by requesting the shadowcasting algorithm to run.

        try shadowcasting.computeFov(start_pos, level.map, &view_ptr.map);

        var bit_iter = view_ptr.map.visible.iterator(.{});
        while (bit_iter.next()) |index| {
            const visible_pos = level.map.fromIndex(index);
            if (try fov.fovCheck(level, id, visible_pos, .high)) {
                view_ptr.high.markVisible(visible_pos);
            }

            if (try fov.fovCheck(level, id, visible_pos, .low)) {
                view_ptr.low.markVisible(visible_pos);
            }
        }
        // Determine which Pov to use based on stance, and update 'explored' to include new tiles.
        if (level.entities.stance.get(id) == .crouching) {
            view_ptr.explored.setUnion(view_ptr.low.visible);
        } else {
            view_ptr.explored.setUnion(view_ptr.high.visible);
        }
    }

    pub fn entityInFov(level: *Level, id: Id, other: Id) FovError!FovResult {
        const stance = level.entities.stance.get(id);
        const other_stance = level.entities.stance.getOrNull(other) orelse Stance.standing;
        var view_height: ViewHeight = undefined;
        if (stance == Stance.crouching or other_stance == Stance.crouching) {
            view_height = .low;
        } else {
            view_height = .high;
        }

        const other_pos = level.entities.pos.get(other);
        return try level.isInFov(id, other_pos, view_height);
    }

    pub fn entitiesAtPos(level: *const Level, pos: Pos, ids: *ArrayList(Id)) !void {
        for (level.entities.ids.items) |id| {
            if (level.entities.pos.getOrNull(id)) |entity_pos| {
                if (entity_pos.eql(pos)) {
                    try ids.append(id);
                }
            }
        }
    }

    pub fn posInFov(level: *Level, id: Id, other_pos: Pos) FovError!FovResult {
        return try level.isInFov(id, other_pos, level.entities.stance.get(id).viewHeight());
    }

    pub fn posExplored(level: *Level, id: Id, pos: Pos) bool {
        return level.entities.view.get(id).isExplored(pos);
    }

    pub fn posInsideFov(level: *Level, id: Id, other_pos: Pos) FovError!bool {
        return try level.posInFov(id, other_pos) == FovResult.inside;
    }

    pub fn isInFov(level: *Level, id: Id, other_pos: Pos, view_height: ViewHeight) FovError!FovResult {
        const in_fov = switch (view_height) {
            .low => level.entities.view.get(id).low.isVisible(other_pos),
            .high => level.entities.view.get(id).high.isVisible(other_pos),
        };

        const start_pos = level.entities.pos.get(id);
        const fov_radius = level.entities.fov_radius.get(id);
        if (in_fov) {
            return FovResult.fromPositions(start_pos, other_pos, fov_radius);
        } else {
            return FovResult.outside;
        }
    }
};
