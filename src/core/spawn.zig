const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const comp = utils.comp;
const Id = comp.Id;
const Comp = comp.Comp;

const math = @import("math");
const Pos = math.pos.Pos;

const Config = @import("config.zig").Config;

const ent = @import("entities.zig");
const Entities = ent.Entities;
const Type = ent.Type;
const Name = ent.Name;

const movement = @import("movement.zig");
const MoveMode = movement.MoveMode;

pub fn spawnPlayer(entities: *Entities, config: *const Config) !void {
    const id = Entities.player_id;
    try entities.ids.append(Entities.player_id);

    try entities.addBasicComponents(id, Pos.init(0, 0), .player, .player);

    entities.blocking.getPtr(id).?.* = true;
    try entities.move_mode.insert(id, MoveMode.walk);
    try entities.next_move_mode.insert(id, MoveMode.walk);
    try entities.move_left.insert(id, 0);
    try entities.energy.insert(id, config.player_energy);
    try entities.stance.insert(id, .standing);
}
