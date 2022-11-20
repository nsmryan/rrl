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

const movement = @import("movement.zig");
const MoveMode = movement.MoveMode;

const fov = @import("fov.zig");
const FovBlock = fov.FovBlock;
const ViewHeight = fov.ViewHeight;
const View = fov.View;

const items = @import("items.zig");
const Item = items.Item;

pub const SkillClass = enum {
    body,
    grass,
    monolith,
    wind,
};

pub const Stance = enum {
    crouching,
    standing,
    running,

    pub fn waited(stance: Stance, move_mode: MoveMode) Stance {
        if (stance == .crouching and move_mode == .run) return .standing;
        if (stance == .standing and move_mode == .sneak) return .crouching;
        if (stance == .running) return .standing;
        return stance;
    }

    pub fn viewHeight(stance: Stance) ViewHeight {
        return switch (stance) {
            .crouching => .low,
            .standing, .running => .high,
        };
    }
};

pub const Turn = struct {
    pass: bool = false,
    walk: bool = false,
    run: bool = false,
    jump: bool = false,
    attack: bool = false,
    skill: bool = false,
    interactTrap: bool = false,
    blink: bool = false,

    pub fn init() Turn {
        return Turn{};
    }

    pub fn any(turn: Turn) bool {
        for (std.meta.fields()) |field| {
            if (@field(turn, field.name)) {
                return true;
            }
        }
        return false;
    }
};

pub const Entities = struct {
    pub const player_id = 0;

    next_id: Id = 1,
    ids: ArrayList(Id),
    pos: Comp(Pos),
    typ: Comp(Type),
    state: Comp(EntityState),
    name: Comp(Name),
    blocking: Comp(bool),
    move_mode: Comp(MoveMode),
    next_move_mode: Comp(MoveMode),
    move_left: Comp(usize),
    turn: Comp(Turn),
    stance: Comp(Stance),
    item: Comp(Item),
    energy: Comp(u32),
    fov_radius: Comp(i32),
    illuminate: Comp(usize),
    facing: Comp(Direction),
    fov_block: Comp(FovBlock),
    view: Comp(View),

    pub fn init(allocator: Allocator) Entities {
        var entities: Entities = undefined;
        entities.next_id = 1;

        comptime var names = compNames(Entities);
        inline for (names) |field_name| {
            @field(entities, field_name) = @TypeOf(@field(entities, field_name)).init(allocator);
        }
        entities.ids = ArrayList(Id).init(allocator);
        return entities;
    }

    pub fn deinit(self: *Entities) void {
        comptime var names = compNames(Entities);
        inline for (names) |field_name| {
            @field(self, field_name).deinit();
        }
        self.ids.deinit();
        self.next_id = 0;
    }

    pub fn clear(self: *Entities) void {
        comptime var names = compNames(Entities);
        inline for (names) |field_name| {
            @field(self, field_name).clear();
        }
        self.ids.clearRetainingCapacity();
        self.next_id = 0;
    }

    pub fn remove(self: *Entities, id: Id) void {
        comptime var names = compNames(Entities);
        inline for (names) |field_name| {
            @field(self, field_name).remove(id);
        }
        const id_index = std.mem.indexOfScalar(Id, self.ids.items, id).?;
        // NOTE(perf) could this be swapRemove?
        _ = self.ids.orderedRemove(id_index);
    }

    pub fn createEntity(self: *Entities, position: Pos, name: Name, typ: Type) !Id {
        const id = self.next_id;
        self.next_id += 1;
        try self.ids.append(id);
        try self.addBasicComponents(id, position, name, typ);
        return id;
    }

    pub fn addBasicComponents(self: *Entities, id: Id, position: Pos, name: Name, typ: Type) !void {
        // Add fields that all entities share.
        try self.pos.insert(id, position);
        try self.typ.insert(id, typ);
        try self.name.insert(id, name);
        try self.blocking.insert(id, false);
        try self.turn.insert(id, Turn.init());
        try self.state.insert(id, .play);
    }

    pub fn idValid(entities: *Entities, id: Id) bool {
        if (utils.comp.binarySearchKeys(id, entities.ids.items) == .found) {
            return entities.state.get(id) == .play;
        } else {
            return false;
        }
    }

    pub fn markForRemoval(entities: *Entities, id: Id) void {
        entities.state.set(id, .remove);
    }
};

test "basic entities" {
    var allocator = std.testing.allocator;
    var entities = Entities.init(allocator);
    defer entities.deinit();

    const id = try entities.createEntity(Pos.init(0, 0), Name.player, Type.player);
    try std.testing.expectEqual(@as(Id, 1), id);
    try std.testing.expectEqual(@as(Id, 2), entities.next_id);
    try std.testing.expectEqual(@as(usize, 1), entities.pos.store.items.len);

    entities.clear();
    try std.testing.expectEqual(@as(Id, 0), entities.next_id);
    try std.testing.expectEqual(@as(usize, 0), entities.pos.store.items.len);
}

test "remove entity" {
    var allocator = std.testing.allocator;
    var entities = Entities.init(allocator);
    defer entities.deinit();

    const id = try entities.createEntity(Pos.init(0, 0), Name.player, Type.player);
    entities.remove(id);
    try std.testing.expectEqual(@as(Id, 2), entities.next_id);
    try std.testing.expectEqual(@as(usize, 0), entities.pos.store.items.len);
}

pub const Type = enum {
    player,
    enemy,
    item,
    column,
    energy,
    trigger,
    environment,
    other,
};

pub const EntityState = enum {
    spawn,
    play,
    remove,
};

// Entity names combine items and remaining entities.
pub const Name = blk: {
    const numFields = @typeInfo(Item).Enum.fields.len + @typeInfo(ExtraNames).Enum.fields.len + @typeInfo(Golems).Enum.fields.len;
    comptime var fields: [numFields]std.builtin.Type.EnumField = undefined;

    comptime var index = 0;
    for (std.meta.fields(Item)) |field| {
        fields[index] = std.builtin.Type.EnumField{ .name = field.name, .value = index };
        index += 1;
    }

    for (std.meta.fields(ExtraNames)) |field| {
        fields[index] = std.builtin.Type.EnumField{ .name = field.name, .value = index };
        index += 1;
    }

    for (std.meta.fields(Golems)) |field| {
        fields[index] = std.builtin.Type.EnumField{ .name = field.name, .value = index };
        index += 1;
    }

    const enumInfo = std.builtin.Type.Enum{
        .layout = std.builtin.Type.ContainerLayout.Auto,
        .tag_type = u8,
        .fields = &fields,
        .decls = &[0]std.builtin.Type.Declaration{},
        .is_exhaustive = true,
    };

    break :blk @Type(std.builtin.Type{ .Enum = enumInfo });
};

pub const Golems = enum {
    gol,
    pawn,
    rook,
    spire,
    armil,
};

pub const ExtraNames = enum {
    player,
    column,
    exit,
    gateTrigger,
    mouse,
    cursor,
    energy,
    grass,
    statue,
    smoke,
    other,
};

//pub const Name = enum {
//    player,
//    gol,
//    pawn,
//    rook,
//    column,
//    key,
//    exit,
//    dagger,
//    hammer,
//    spear,
//    greatSword,
//    sword,
//    shield,
//    lantern,
//    thumper,
//    axe,
//    khopesh,
//    sling,
//    seedOfStone,
//    seedCache,
//    smokeBomb,
//    lookingGlass,
//    glassEye,
//    teleporter,
//    spire,
//    armil,
//    spikeTrap,
//    blinkTrap,
//    freezeTrap,
//    soundTrap,
//    gateTrigger,
//    stone,
//    mouse,
//    cursor,
//    energy,
//    herb,
//    grass,
//    statue,
//    smoke,
//    magnifier,
//    other,
//};
pub fn compNames(comptime T: type) [][]const u8 {
    const fieldInfos = std.meta.fields(T);
    comptime var names: [fieldInfos.len][]const u8 = undefined;

    comptime var index: usize = 0;

    comptime {
        inline for (fieldInfos) |field| {
            if (!std.mem.eql(u8, "ids", field.name) and !std.mem.eql(u8, "next_id", field.name)) {
                names[index] = field.name;
                index += 1;
            }
        }
    }

    return names[0..index];
}
