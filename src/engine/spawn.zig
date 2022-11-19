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

const board = @import("board");
const View = board.fov.View;

const messaging = @import("messaging.zig");
const MsgLog = messaging.MsgLog;

const core = @import("core");
const MoveMode = core.movement.MoveMode;
const Entities = core.entities.Entities;
const Type = core.entities.Type;
const Name = core.entities.Name;
const Config = core.config.Config;

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

    try log.log(.spawn, .{ id, Name.player });
}
