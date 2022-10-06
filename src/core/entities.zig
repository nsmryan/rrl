const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const comp = utils.comp;
const Id = comp.Id;
const Comp = comp.Comp;
const Pos = utils.pos.Pos;

const Entities = struct {
    next_id: Id = 0,
    ids: ArrayList(Id),
    pos: Comp(Pos),
    typ: Comp(Type),
    name: Comp(Name),

    pub fn init(allocator: Allocator) Entities {
        var entities: Entities = undefined;
        entities.next_id = 0;

        inline for (std.meta.fields(Entities)) |field| {
            if (@typeInfo(field.field_type) != .Struct) {
                continue;
            }
            if (!std.mem.eql(u8, field.name, "next_id")) {
                @field(entities, field.name) = field.field_type.init(allocator);
            }
        }
        return entities;
    }

    pub fn deinit(self: *Entities) void {
        inline for (std.meta.fields(Entities)) |field| {
            if (@typeInfo(field.field_type) != .Struct) {
                continue;
            }
            if (!std.mem.eql(u8, field.name, "next_id")) {
                @field(self, field.name).deinit();
            }
        }
        self.next_id = 0;
    }

    pub fn clear(self: *Entities) void {
        inline for (std.meta.fields(Entities)) |field| {
            if (@typeInfo(field.field_type) != .Struct) {
                continue;
            }
            if (@hasField(field.field_type, "clear")) {
                @field(self, field.name).clear();
            }
        }
        self.next_id = 0;
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

    const id = try entities.createEntity(Pos.init(0, 0), Name.Player, Type.Player);
    try std.testing.expectEqual(@as(Id, 0), id);
    try std.testing.expectEqual(@as(Id, 1), entities.next_id);
    try std.testing.expectEqual(@as(usize, 1), entities.pos.store.items.len);

    entities.clear();
    try std.testing.expectEqual(@as(Id, 0), entities.next_id);
    //try std.testing.expectEqual(@as(usize, 0), entities.pos.store.items.len);
}

pub const Type = enum {
    Player,
    Enemy,
    Item,
    Column,
    Energy,
    Trigger,
    Environment,
    Other,
};

pub const Name = enum {
    Player,
    Gol,
    Pawn,
    Rook,
    Column,
    Key,
    Exit,
    Dagger,
    Hammer,
    Spear,
    GreatSword,
    Sword,
    Shield,
    Lantern,
    Thumper,
    Axe,
    Khopesh,
    Sling,
    SeedOfStone,
    SeedCache,
    SmokeBomb,
    LookingGlass,
    GlassEye,
    Teleporter,
    Spire,
    Armil,
    SpikeTrap,
    BlinkTrap,
    FreezeTrap,
    SoundTrap,
    GateTrigger,
    Stone,
    Mouse,
    Cursor,
    Energy,
    Herb,
    Grass,
    Statue,
    Smoke,
    Magnifier,
    Other,
};
