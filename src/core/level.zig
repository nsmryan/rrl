const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const board = @import("board");
const Map = board.map.Map;
const blocking = board.blocking;
const BlockedType = board.blocking.BlockedType;

const utils = @import("utils");
const Id = utils.comp.Id;

const core = @import("core");
const Pos = core.pos.Pos;
const Direction = core.direction.Direction;
const Collision = core.movement.Collision;
const HitWall = core.movement.HitWall;

const Entities = @import("entities.zig").Entities;

pub const Level = struct {
    map: Map,
    entities: Entities,

    pub fn init(map: Map, entities: Entities) Level {
        return Level{ .map = map, .entities = entities };
    }

    pub fn empty(allocator: Allocator) Level {
        return Level.init(Map.empty(), Entities.init(allocator));
    }

    pub fn fromDims(width: i32, height: i32, allocator: Allocator) !Level {
        return Level.init(Map.fromDims(width, height, allocator), Entities.init(allocator));
    }

    pub fn checkCollision(level: *Level, pos: Pos, dir: Direction) Collision {
        var collision: Collision = Collision.init(pos, dir);
        if (blocking.moveBlocked(&level.map, pos, dir, BlockedType.move)) |blocked| {
            collision.wall = HitWall.init(blocked.height, blocked.blocked_tile);
        }

        collision.entity = level.blockingEntityAt(pos);

        return collision;
    }

    pub fn blockingEntityAt(level: *Level, pos: Pos) bool {
        for (level.entities.id.items) |id| {
            if (level.entities.pos.get(id)) |entity_pos| {
                if (entity_pos == pos and level.entities.blocking.has(id)) {
                    return true;
                }
            }
        }
        return false;
    }
};
