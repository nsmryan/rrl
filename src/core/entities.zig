const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const comp = utils.comp;
const Id = comp.Id;
const Comp = comp.Comp;

const math = @import("math");
const Pos = math.pos.Pos;

pub const EntityClass = enum {
    body,
    grass,
    monolith,
    wind,
};

pub const Entities = struct {
    next_id: Id = 0,
    ids: ArrayList(Id),
    pos: Comp(Pos),
    typ: Comp(Type),
    name: Comp(Name),

    pub fn init(allocator: Allocator) Entities {
        var entities: Entities = undefined;
        entities.next_id = 0;

        comptime var names = compNames();
        inline for (names) |field_name| {
            @field(entities, field_name) = @TypeOf(@field(entities, field_name)).init(allocator);
        }
        entities.ids = ArrayList(Id).init(allocator);
        return entities;
    }

    pub fn deinit(self: *Entities) void {
        comptime var names = compNames();
        inline for (names) |field_name| {
            @field(self, field_name).deinit();
        }
        self.ids.deinit();
        self.next_id = 0;
    }

    pub fn clear(self: *Entities) void {
        comptime var names = compNames();
        inline for (names) |field_name| {
            @field(self, field_name).clear();
        }
        self.ids.clearRetainingCapacity();
        self.next_id = 0;
    }

    fn compNames() [][]const u8 {
        const fieldInfos = std.meta.fields(Entities);
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

    pub fn remove(self: *Entities, id: Id) void {
        comptime var names = compNames();
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

        // Add fields that all entities share.
        try self.pos.insert(id, position);
        try self.typ.insert(id, typ);
        try self.name.insert(id, name);

        return id;
    }
};

test "basic entities" {
    var allocator = std.testing.allocator;
    var entities = Entities.init(allocator);
    defer entities.deinit();

    const id = try entities.createEntity(Pos.init(0, 0), Name.player, Type.player);
    try std.testing.expectEqual(@as(Id, 0), id);
    try std.testing.expectEqual(@as(Id, 1), entities.next_id);
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
    try std.testing.expectEqual(@as(Id, 1), entities.next_id);
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

pub const Name = enum {
    player,
    gol,
    pawn,
    rook,
    column,
    key,
    exit,
    dagger,
    hammer,
    spear,
    greatSword,
    sword,
    shield,
    lantern,
    thumper,
    axe,
    khopesh,
    sling,
    seedOfStone,
    seedCache,
    smokeBomb,
    lookingGlass,
    glassEye,
    teleporter,
    spire,
    armil,
    spikeTrap,
    blinkTrap,
    freezeTrap,
    soundTrap,
    gateTrigger,
    stone,
    mouse,
    cursor,
    energy,
    herb,
    grass,
    statue,
    smoke,
    magnifier,
    other,
};
