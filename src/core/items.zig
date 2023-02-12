const std = @import("std");

const core = @import("core");
const EntityName = core.entities.EntityName;
const WeaponType = core.entities.WeaponType;
const Config = core.config.Config;

const utils = @import("utils");
const comp = utils.comp;
const Id = comp.Id;

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
            .stone, .key => return ItemClass.misc,
            .dagger, .shield, .hammer, .spear, .greatSword, .sword, .axe, .khopesh, .sling => return ItemClass.primary,
            .teleporter, .herb, .seedOfStone, .seedCache, .smokeBomb, .lookingGlass, .glassEye, .lantern, .thumper, .spikeTrap, .soundTrap, .blinkTrap, .freezeTrap => return ItemClass.consumable,
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

pub const InventorySlot = enum(u8) {
    weapon,
    throwing,
    artifact0,
    artifact1,
};

pub const Inventory = struct {
    weapon: ?Id = null,
    throwing: ?Id = null,
    artifacts: [2]?Id = [2]?Id{ null, null },

    pub fn addItem(inventory: *Inventory, item_id: Id, class: ItemClass) ?Id {
        var displaced: ?Id = null;
        switch (class) {
            .primary => {
                displaced = inventory.weapon;
                inventory.weapon = item_id;
            },

            .consumable => {
                displaced = inventory.throwing;
                inventory.throwing = item_id;
            },

            .misc => {
                if (inventory.artifacts[0] == null) {
                    inventory.artifacts[0] = item_id;
                } else if (inventory.artifacts[1] == null) {
                    inventory.artifacts[1] = item_id;
                } else {
                    displaced = inventory.artifacts[1];
                    inventory.artifacts[1] = item_id;
                }
            },
        }

        return displaced;
    }

    pub fn drop(inventory: *Inventory, item_id: Id, class: ItemClass) void {
        switch (class) {
            .primary => {
                inventory.weapon = null;
            },

            .consumable => {
                inventory.throwing = null;
            },

            .misc => {
                var index: usize = 0;
                if (inventory.artifacts[0] != item_id) {
                    index = 1;
                }
                inventory.artifacts[index] = null;
            },
        }
    }
};
