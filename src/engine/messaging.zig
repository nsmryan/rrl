const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const math = @import("math");
const Direction = math.direction.Direction;
const Pos = math.pos.Pos;

const utils = @import("utils");
const Id = utils.comp.Id;

const core = @import("core");
const Skill = core.skills.Skill;
const Talent = core.talents.Talent;
const ItemClass = core.items.ItemClass;
const InventorySlot = core.items.InventorySlot;
const MoveMode = core.movement.MoveMode;
const MoveType = core.movement.MoveType;
const Stance = core.entities.Stance;
const Behavior = core.entities.Behavior;
const Name = core.entities.Name;
const Entities = core.entities.Entities;
const items = core.items;
const WeaponType = items.WeaponType;
const AttackStyle = items.AttackStyle;

pub const Msg = union(enum) {
    tryMove: struct { id: Id, dir: Direction, amount: usize },
    collided: struct { id: Id, pos: Pos },
    faceTowards: struct { id: Id, pos: Pos },
    jumpWall: struct { id: Id, from: Pos, to: Pos },
    move: struct { id: Id, move_type: MoveType, move_mode: MoveMode, pos: Pos },
    gainEnergy: struct { id: Id, amount: u32 },
    sound: struct { id: Id, pos: Pos, amount: usize },
    stance: struct { id: Id, stance: Stance },
    nextMoveMode: struct { id: Id, move_mode: MoveMode },
    pass: Id,
    spawn: struct { id: Id, name: Name },
    newLevel: void,
    startLevel: void,
    facing: struct { id: Id, facing: Direction },
    endTurn: void,
    cursorStart: Pos,
    cursorEnd,
    cursorMove: Pos,
    pickup: Id,
    pickedUp: struct { id: Id, item_id: Id, slot: items.InventorySlot },
    dropItem: struct { id: Id, item_id: Id, slot: items.InventorySlot },
    droppedItem: struct { id: Id, slot: items.InventorySlot },
    dropFailed: struct { id: Id, item_id: Id },
    eatHerb: struct { id: Id, item_id: Id },
    startUseItem: InventorySlot,
    hammerRaise: struct { id: Id, dir: Direction },
    hammerSwing: struct { id: Id, pos: Pos },
    notEnoughEnergy: Id,
    placeTrap: struct { id: Id, pos: Pos, trap_id: Id },
    itemThrow: struct { id: Id, item_id: Id, start: Pos, end: Pos, hard: bool },
    hit: struct { id: Id, start_pos: Pos, hit_pos: Pos, weapon_type: WeaponType, attack_style: AttackStyle },
    itemLanded: struct { id: Id, start: Pos, hit: Pos },
    yell: Id,
    remove: Id,
    interact: struct { id: Id, interact_pos: Pos },
    hammerHitWall: struct { id: Id, start_pos: Pos, end_pos: Pos, dir: Direction },
    hammerHitEntity: struct { id: Id, hit_entity: Id },
    crushed: struct { id: Id, pos: Pos },
    killed: struct { id: Id, crushed_id: Id, hp: usize },
    aiStep: Id,
    behaviorChange: struct { id: Id, behavior: Behavior },
    stun: struct { id: Id, num_turns: usize },
    pushed: struct { attacker: Id, attacked: Id, dir: Direction, amount: usize },
    pierce: struct { origin_pos: Pos, hit_pos: Pos },
    slash: struct { origin_pos: Pos, hit_pos: Pos },
    blunt: struct { origin_pos: Pos, hit_pos: Pos },
    aiAttack: struct { id: Id, target_id: Id },

    pub fn genericMsg(comptime msg_type: MsgType, args: anytype) Msg {
        const fields = std.meta.fields(Msg);

        const field_type = fields[@enumToInt(msg_type)].field_type;
        const field_type_info = @typeInfo(field_type);

        var value: field_type = undefined;

        const arg_type_info = @typeInfo(@TypeOf(args));
        // NOTE(zig) std.meta.trait.isTuple returns false here for some reason.
        if (arg_type_info == .Struct and arg_type_info.Struct.is_tuple) {
            comptime var index = 0;
            inline while (index < args.len) {
                @field(value, field_type_info.Struct.fields[index].name) = args[index];
                index += 1;
            }
        } else {
            value = args;
        }

        return @unionInit(Msg, @tagName(msg_type), value);
    }

    pub fn consoleMessage(msg: Msg, entities: *const Entities, buf: []u8) std.fmt.BufPrintError![]u8 {
        switch (msg) {
            .pass => {
                return try std.fmt.bufPrint(buf, "Player passed their turn", .{});
            },

            .move => |params| {
                return try std.fmt.bufPrint(buf, "{s} moved to {}, {}", .{ @tagName(entities.typ.get(params.id)), params.pos.x, params.pos.y });
            },

            .gainEnergy => |params| {
                return try std.fmt.bufPrint(buf, "{s} gained {} energy", .{ @tagName(entities.typ.get(params.id)), params.amount });
            },

            .collided => |params| {
                return try std.fmt.bufPrint(buf, "{s} collided with something!", .{@tagName(entities.typ.get(params.id))});
            },

            else => {},
        }
        return &.{};
    }
};

pub const MsgType = std.meta.Tag(Msg);

pub const MsgLog = struct {
    remaining: ArrayList(Msg),
    instant: ArrayList(Msg),
    all: ArrayList(Msg),

    pub fn init(allocator: Allocator) MsgLog {
        return MsgLog{
            .remaining = ArrayList(Msg).init(allocator),
            .instant = ArrayList(Msg).init(allocator),
            .all = ArrayList(Msg).init(allocator),
        };
    }

    pub fn deinit(msg_log: *MsgLog) void {
        msg_log.remaining.deinit();
        msg_log.instant.deinit();
        msg_log.all.deinit();
    }

    pub fn pop(msg_log: *MsgLog) !?Msg {
        // First attempt to get a message from the 'instant' log to empty it first.
        // Then attempt to get from the main log, remaining.
        // If a message is retrieved, log it in 'all' as the final ordering of message
        // processing.
        var msg: ?Msg = undefined;
        // NOTE(performance) this ordered remove is O(n). A dequeue would be better.
        if (msg_log.instant.items.len > 0) {
            msg = msg_log.instant.orderedRemove(0);
        } else if (msg_log.remaining.items.len > 0) {
            msg = msg_log.remaining.orderedRemove(0);
        } else {
            msg = null;
        }
        if (msg) |valid_msg| {
            try msg_log.all.append(valid_msg);
        }
        return msg;
    }

    pub fn log(msg_log: *MsgLog, comptime msg_type: MsgType, args: anytype) !void {
        try msg_log.remaining.append(Msg.genericMsg(msg_type, args));
    }

    pub fn now(msg_log: *MsgLog, comptime msg_type: MsgType, args: anytype) !void {
        try msg_log.instant.append(Msg.genericMsg(msg_type, args));
    }

    pub fn rightNow(msg_log: *MsgLog, comptime msg_type: MsgType, args: anytype) !void {
        try msg_log.instant.insert(0, Msg.genericMsg(msg_type, args));
    }

    pub fn record(msg_log: *MsgLog, comptime msg_type: MsgType, args: anytype) !void {
        try msg_log.all.append(Msg.genericMsg(msg_type, args));
    }

    pub fn clear(msg_log: *MsgLog) void {
        msg_log.remaining.clearRetainingCapacity();
        msg_log.instant.clearRetainingCapacity();
        msg_log.all.clearRetainingCapacity();
    }
};
