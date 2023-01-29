const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const comp = utils.comp;
const Id = comp.Id;
const Comp = comp.Comp;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const Dims = math.utils.Dims;

const messaging = @import("messaging.zig");
const MsgLog = messaging.MsgLog;

const core = @import("core");
const MoveMode = core.movement.MoveMode;
const MoveType = core.movement.MoveType;
const Entities = core.entities.Entities;
const Type = core.entities.Type;
const Name = core.entities.Name;
const Config = core.config.Config;
const View = core.fov.View;

pub fn spawnPlayer(entities: *Entities, log: *MsgLog, config: *const Config, allocator: Allocator) !void {
    const id = Entities.player_id;
    try entities.ids.append(Entities.player_id);

    try entities.addBasicComponents(id, Pos.init(0, 0), .player, .player);

    entities.blocking.getPtr(id).* = true;
    try entities.move_mode.insert(id, MoveMode.walk);
    try entities.next_move_mode.insert(id, MoveMode.walk);
    try entities.move_left.insert(id, 0);
    try entities.energy.insert(id, config.player_energy);
    try entities.stance.insert(id, .standing);
    try entities.fov_radius.insert(id, config.fov_radius_player);
    try entities.facing.insert(id, Direction.right);
    try entities.view.insert(id, try View.init(Dims.init(0, 0), allocator));
    try entities.hp.insert(id, @intCast(usize, config.player_health));

    try log.log(.spawn, .{ id, Name.player });
    try log.log(.stance, .{ id, entities.stance.get(id) });
    try log.log(.facing, .{ id, entities.facing.get(id) });
    try log.log(.move, .{ id, MoveType.blink, MoveMode.walk, Pos.init(0, 0) });
}

pub fn spawnSword(entities: *Entities, log: *MsgLog, config: *const Config, allocator: Allocator) !void {
    _ = config;
    _ = allocator;

    const id = try entities.createEntity(Pos.init(0, 0), .sword, .item);

    try log.log(.spawn, .{ id, .sword });
    try log.log(.move, .{ id, MoveType.blink, MoveMode.walk, Pos.init(0, 0) });
}
