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
const GolemName = core.entities.GolemName;
const Config = core.config.Config;
const View = core.fov.View;
const Inventory = core.items.Inventory;
const Item = core.items.Item;
const Reach = core.movement.Reach;

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
    try entities.inventory.insert(id, Inventory{});

    try log.log(.spawn, .{ id, Name.player });
    try log.log(.stance, .{ id, entities.stance.get(id) });
    try log.log(.facing, .{ id, entities.facing.get(id) });
    try log.log(.move, .{ id, MoveType.blink, MoveMode.walk, Pos.init(0, 0) });
}

pub fn spawnItem(entities: *Entities, item: Item, log: *MsgLog, config: *const Config, allocator: Allocator) !Id {
    _ = config;
    _ = allocator;

    // Item names are included in the entity Name type, so this convertion will find the Name for the given Item.
    const name = std.meta.stringToEnum(Name, std.meta.tagName(item)).?;

    const id = try entities.createEntity(Pos.init(0, 0), name, .item);
    entities.blocking.getPtr(id).* = false;
    try entities.item.insert(id, item);

    try log.log(.spawn, .{ id, name });
    try log.log(.move, .{ id, MoveType.blink, MoveMode.walk, Pos.init(0, 0) });

    return id;
}

pub fn spawnGrass(entities: *Entities, log: *MsgLog) !Id {
    const id = try entities.createEntity(Pos.init(0, 0), .grass, .environment);
    entities.blocking.getPtr(id).* = false;

    try log.log(.spawn, .{ id, .grass });
    try log.log(.move, .{ id, MoveType.blink, MoveMode.walk, Pos.init(0, 0) });

    return id;
}

pub fn spawnSmoke(entities: *Entities, config: *const Config, pos: Pos, amount: usize, log: *MsgLog) !Id {
    const id = try entities.createEntity(pos, .smoke, .environment);

    try entities.fov_block.insert(id, core.fov.FovBlock{ .opaqu = amount });
    try entities.count_down.insert(id, config.smoke_turns);
    try log.log(.move, .{ id, MoveType.blink, MoveMode.walk, pos });
    try log.log(.spawn, .{ id, .smoke });

    return id;
}

pub fn spawnGolem(entities: *Entities, config: *const Config, pos: Pos, golem: GolemName, log: *MsgLog, allocator: Allocator) !Id {
    const name = std.meta.stringToEnum(Name, @tagName(golem)).?;
    const id = try entities.createEntity(pos, name, .enemy);

    entities.blocking.getPtr(id).* = true;
    try entities.fov_radius.insert(id, config.fov_radius_golem);
    try entities.facing.insert(id, Direction.right);
    try entities.behavior.insert(id, .idle);
    try entities.hp.insert(id, @intCast(usize, config.golem_health));
    try entities.movement.insert(id, Reach{ .single = config.gol_move_distance });
    try entities.attack.insert(id, Reach{ .diag = config.gol_attack_distance });
    try entities.view.insert(id, try View.init(Dims.init(0, 0), allocator));
    try entities.stance.insert(id, .standing);

    try log.log(.facing, .{ id, entities.facing.get(id) });
    try log.log(.stance, .{ id, entities.stance.get(id) });
    try log.log(.move, .{ id, MoveType.blink, MoveMode.walk, pos });
    try log.log(.spawn, .{ id, .gol });

    return id;
}
