const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const board = @import("board");
const Map = board.map.Map;
const blocking = board.blocking;
const BlockedType = board.blocking.BlockedType;

const utils = @import("utils");
const Id = utils.comp.Id;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const movement = @import("movement.zig");
const Collision = movement.Collision;
const HitWall = movement.HitWall;

const Entities = @import("entities.zig").Entities;

pub const Level = struct {
    map: Map,
    entities: Entities,

    pub fn init(map: Map, entities: Entities) Level {
        return Level{ .map = map, .entities = entities };
    }

    pub fn deinit(level: *Level) void {
        level.map.deinit();
        level.entities.deinit();
    }

    pub fn empty(allocator: Allocator) Level {
        return Level.init(Map.empty(allocator), Entities.init(allocator));
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
        for (level.entities.ids.items) |id| {
            if (level.entities.pos.get(id)) |entity_pos| {
                if (entity_pos.eql(pos) and level.entities.blocking.has(id)) {
                    return true;
                }
            }
        }
        return false;
    }
};
