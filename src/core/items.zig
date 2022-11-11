const std = @import("std");

const core = @import("core");
const EntityName = core.entities.EntityName;
const WeaponType = core.entities.WeaponType;
const Config = core.config.Config;

pub const ItemClass = enum(u8) {
    primary,
    consumable,
    misc,
};

pub const Item = enum {
    stone,
    key,
    dagger,
    shield,
    hammer,
    spear,
    greatSword,
    axe,
    khopesh,
    sword,
    lantern,
    thumper,
    sling,
    teleporter,
    herb,
    seedOfStone,
    seedCache,
    smokeBomb,
    lookingGlass,
    glassEye,
    spikeTrap,
    soundTrap,
    blinkTrap,
    freezeTrap,

    pub fn class(item: Item) ItemClass {
        switch (item) {
            .stone, .key => ItemClass.misc,
            .dagger, .shield, .hammer, .spear, .greatSword, .sword, .axe, .khopesh, .sling => ItemClass.primary,
            .teleporter, .herb, .seedOfStone, .seedCache, .smokeBomb, .lookingGlass, .glassEye, .lantern, .thumper, .spikeTrap, .soundTrap, .blinkTrap, .freezeTrap => ItemClass.consumable,
        }
    }

    pub fn name(item: Item) EntityName {
        for (std.meta.fields(EntityName)) |field| {
            if (std.mem.eql(field.name, @tagName(item))) {
                return field.value;
            }
        }
    }

    pub fn weaponType(item: Item) ?WeaponType {
        switch (item) {
            .spear => WeaponType.pierce,
            .dagger, .shield, .greatSword, .sword, .axe, .khopesh => WeaponType.slash,
            .sling, .hammer => WeaponType.blunt,
            else => null,
        }
    }

    pub fn isTrap(item: Item) bool {
        switch (item) {
            .spikeTrap, .soundTrap, .blinkTrap, .freezeTrap => true,
            else => false,
        }
    }

    pub fn throwStunTurns(item: Item, config: *Config) usize {
        switch (item) {
            .stone => config.stun_turns_throw_stone,
            .spear => config.stun_turns_throw_spear,
            else => config.stun_turns_throw_default,
        }
    }
};
