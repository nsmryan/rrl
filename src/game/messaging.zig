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
const MoveMode = core.movement.MoveMode;
const MoveType = core.movement.MoveType;
const Stance = core.entities.Stance;

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
};
