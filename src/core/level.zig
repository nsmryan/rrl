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
const FloodFill = board.floodfill.FloodFill;

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

        collision.entity = level.blockingEntityAtPos(dir.move(pos)) != null;

        return collision;
    }

    pub fn checkCollisionLine(level: *const Level, start: Pos, end: Pos, include_end: bool) Collision {
        var line = Line.init(start, end, false);
        var prev = start;
        var collision = Collision.init(start, Direction.fromPositions(start, end).?);
        while (line.next()) |line_pos| {
            if (!include_end and line_pos.eql(end)) {
                break;
            }

            collision = level.checkCollision(prev, Direction.fromPositions(prev, line_pos).?);
            if (collision.hit()) {
                break;
            }
            prev = line_pos;
        }
        return collision;
    }

    // NOTE(design) this may be useful for blink, where we care about whether a tile blocks but
    // not whether we can move into a tile. Use checkCollision for moving into a tile.
    //pub fn posBlockedMove(level: *const Level, pos: Pos) bool {
    //    const in_map = level.map.isWithinBounds(pos);
    //    const blocked_by_entity = level.blockingEntityAtPos(pos) != null;
    //    const blocked_by_map = BlockedType.move.tileBlocks(level.map.get(pos)) == .empty;
    //    return in_map or blocked_by_entity or blocked_by_map;
    //}

    pub fn itemAtPos(level: *const Level, pos: Pos) ?Id {
        for (level.entities.item.ids.items) |id| {
            if (level.entities.status.get(id).active and level.entities.pos.get(id).eql(pos)) {
                return id;
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

        const start_pos = level.entities.pos.get(id);

        var view_ptr = level.entities.view.getPtr(id);
        try view_ptr.resize(level.map.dims());

        view_ptr.low.clear();
        view_ptr.high.clear();
        // NOTE 'map' is cleared by requesting the shadowcasting algorithm to run.

        try shadowcasting.computeFov(start_pos, level.map, &view_ptr.map);

        const fov_radius = level.entities.fov_radius.get(id);

        var bit_iter = view_ptr.map.visible.iterator(.{});
        while (bit_iter.next()) |index| {
            const visible_pos = level.map.fromIndex(index);
            const dist = start_pos.distanceMaximum(visible_pos);

            // Include a check for distances 1 greater then the fov radius so we can
            // know when a tile is on the edge of the FoV.
            // NOTE(perf) filtering out tiles here is a huge optimization.
            if (dist <= fov_radius + 1) {
                if (try fov.fovCheck(level, id, visible_pos, .high)) {
                    view_ptr.high.markVisible(visible_pos);
                }

                if (try fov.fovCheck(level, id, visible_pos, .low)) {
                    view_ptr.low.markVisible(visible_pos);
                }
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
        // Inactive entities are never in FoV.
        if (!level.entities.status.get(other).active) {
            return .outside;
        }

        const stance = level.entities.stance.get(id);
        const other_stance = level.entities.stance.getOrNull(other) orelse Stance.standing;
        var view_height: ViewHeight = undefined;
        if (stance == .crouching or other_stance == .crouching) {
            view_height = .low;
        } else {
            view_height = .high;
        }

        const other_pos = level.entities.pos.get(other);
        return try level.isInFov(id, other_pos, view_height);
    }

    pub fn entitiesAtPos(level: *const Level, pos: Pos, ids: *ArrayList(Id)) !void {
        ids.clearRetainingCapacity();
        for (level.entities.ids.items) |id| {
            if (level.entities.pos.getOrNull(id)) |entity_pos| {
                if (entity_pos.eql(pos)) {
                    try ids.append(id);
                }
            }
        }
    }

    pub fn throwTowards(level: *const Level, start: Pos, end: Pos) Pos {
        var hit_pos = start;

        var line = Line.init(start, end, false);
        while (line.next()) |pos| {
            if (!level.map.isWithinBounds(pos)) {
                break;
            }

            const moveDir = Direction.fromPositions(hit_pos, pos).?;
            if (level.blockingEntityAtPos(pos)) |hit_entity| {
                if (level.entities.typ.get(hit_entity) != .column) {
                    // Hitting an entity results in the entities tile, except for columns.
                    hit_pos = pos;
                }

                break;
            } else if (blocking.moveBlocked(&level.map, hit_pos, moveDir, .move) != null) {
                break;
            }

            hit_pos = pos;
        }

        return hit_pos;
    }

    pub fn firstEntityTypeAtPos(level: *const Level, pos: Pos, typ: entities.Type) ?Id {
        for (level.entities.ids.items) |id| {
            if (level.entities.status.get(id).active) {
                if (level.entities.pos.getOrNull(id)) |entity_pos| {
                    if (entity_pos.eql(pos) and typ == level.entities.typ.get(id)) {
                        return id;
                    }
                }
            }
        }
        return null;
    }

    pub fn entityNameAtPos(level: *const Level, pos: Pos, name: entities.Name) ?Id {
        for (level.entities.ids.items) |id| {
            if (level.entities.status.get(id).active) {
                if (level.entities.pos.getOrNull(id)) |entity_pos| {
                    if (entity_pos.eql(pos) and name == level.entities.name.get(id)) {
                        return id;
                    }
                }
            }
        }
        return null;
    }

    pub fn blockingEntityAtPos(level: *const Level, pos: Pos) ?Id {
        for (level.entities.ids.items) |id| {
            if (level.entities.status.get(id).active) {
                if (level.entities.pos.getOrNull(id)) |entity_pos| {
                    if (entity_pos.eql(pos) and level.entities.blocking.get(id)) {
                        return id;
                    }
                }
            }
        }
        return null;
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
        // If the entity is in test mode, it can see all tiles.
        if (level.entities.status.get(id).test_mode) {
            return .inside;
        }

        const in_fov = switch (view_height) {
            .low => level.entities.view.get(id).low.isVisible(other_pos),
            .high => level.entities.view.get(id).high.isVisible(other_pos),
        };

        const start_pos = level.entities.pos.get(id);
        const fov_radius = level.entities.fov_radius.get(id);
        // If in Fov, determine if inside or on edge of view using FoV radius.
        if (in_fov) {
            return FovResult.fromPositions(start_pos, other_pos, fov_radius);
        } else {
            return FovResult.outside;
        }
    }

    pub fn searchForEmptyTile(level: *const Level, pos: Pos, max_dist: usize, allocator: Allocator) !?Pos {
        var dist: usize = 1;
        var floodfill = FloodFill.init(allocator);
        // NOTE(perf) a perhaps more efficient implementation would be to flood fill once and sort by
        // distance, rather then flood filling for each successive distance.
        while (dist < max_dist) {
            try floodfill.fill(&level.map, pos, dist);

            for (floodfill.flood.items) |cur| {
                if (level.itemAtPos(cur.pos) == null) {
                    return cur.pos;
                }
            }

            dist += 1;
        }
        return null;
    }
};
