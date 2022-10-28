const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const comp = utils.comp;
const Id = comp.Id;
const Comp = comp.Comp;

const math = @import("math");
const Pos = math.pos.Pos;

const ent = @import("entities.zig");
const Entities = ent.Entities;
const Type = ent.Type;
const Name = ent.Name;

pub fn spawnPlayer(entities: *Entities, position: Pos) !Id {
    return try entities.createEntity(position, Name.player, Type.player);
}
