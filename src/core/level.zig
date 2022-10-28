const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const board = @import("board");
const Map = board.map.Map;

const utils = @import("utils");
const Id = utils.comp.Id;
const Pos = utils.pos.Pos;

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
};
