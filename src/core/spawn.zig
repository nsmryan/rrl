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

const movement = @import("movement.zig");
const MoveMode = movement.MoveMode;

pub fn spawnPlayer(entities: *Entities) !void {
    const id = Entities.player_id;
    try entities.ids.append(Entities.player_id);

    try entities.pos.insert(id, Pos.init(0, 0));
    try entities.typ.insert(id, .player);
    try entities.name.insert(id, .player);
    try entities.move_mode.insert(id, MoveMode.walk);
    try entities.move_left.insert(id, 0);
    try entities.blocking.insert(id, true);
}
