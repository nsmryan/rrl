const std = @import("std");

const entities = @import("entities.zig");
const EntityName = entities.EntityName;
const Config = @import("config.zig").Config;

const utils = @import("utils");
const comp = utils.comp;
const Id = comp.Id;

pub const ItemClass = enum(u8) {
    primary,
    consumable,
    misc,
};

pub const AttackStyle = enum {
    stealth,
    normal,
    strong,
};

pub const WeaponType = enum {
    pierce,
    slash,
    blunt,

    pub fn sharp(weapon_type: WeaponType) bool {
        return weapon_type == .slash or weapon_type == .pierce;
    }
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
            .key => return ItemClass.misc,
            .dagger, .shield, .hammer, .spear, .greatSword, .sword, .axe, .khopesh, .sling => return ItemClass.primary,
            .stone, .teleporter, .herb, .seedOfStone, .seedCache, .smokeBomb, .lookingGlass, .glassEye, .lantern, .thumper, .spikeTrap, .soundTrap, .blinkTrap, .freezeTrap => return ItemClass.consumable,
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
            .spear => return WeaponType.pierce,
            .dagger, .shield, .greatSword, .sword, .axe, .khopesh => return WeaponType.slash,
            .sling, .hammer => return WeaponType.blunt,
            else => return null,
        }
    }

    pub fn isTrap(item: Item) bool {
        switch (item) {
            .spikeTrap, .soundTrap, .blinkTrap, .freezeTrap => true,
            else => false,
        }
    }

    pub fn throwStunTurns(item: Item, config: *Config) usize {
        return switch (item) {
            .stone => config.stun_turns_throw_stone,
            .spear => config.stun_turns_throw_spear,
            else => config.stun_turns_throw_default,
        };
    }

    pub fn isThrowable(item: Item) bool {
        return item == .stone or item == .lantern or item == .seedOfStone or item == .seedCache or
            item == .herb or item == .glassEye or item == .smokeBomb or item == .lookingGlass or
            item == .thumper or item == .teleporter;
    }
};

pub const InventorySlot = enum(u8) {
    weapon,
    throwing,
    artifact0,
    artifact1,
};

pub const InventoryAccess = struct {
    id: ?Id = null,
    slot: InventorySlot = InventorySlot.weapon,
};

pub const Inventory = struct {
    weapon: ?Id = null,
    throwing: ?Id = null,
    artifacts: [2]?Id = [2]?Id{ null, null },

    pub fn accessSlot(inventory: *const Inventory, slot: InventorySlot) ?Id {
        switch (slot) {
            .weapon => return inventory.weapon,
            .throwing => return inventory.throwing,
            .artifact0 => return inventory.artifacts[0],
            .artifact1 => return inventory.artifacts[1],
        }
    }

    pub fn addItem(inventory: *Inventory, item_id: Id, class: ItemClass) InventoryAccess {
        var access: InventoryAccess = InventoryAccess{};
        switch (class) {
            .primary => {
                access.id = inventory.weapon;
                access.slot = InventorySlot.weapon;
                inventory.weapon = item_id;
            },

            .consumable => {
                access.id = inventory.throwing;
                access.slot = InventorySlot.throwing;
                inventory.throwing = item_id;
            },

            .misc => {
                if (inventory.artifacts[0] == null) {
                    // If nothing in first artifact slot, use it.
                    access.id = inventory.artifacts[0];
                    access.slot = InventorySlot.artifact0;
                    inventory.artifacts[0] = item_id;
                } else if (inventory.artifacts[1] == null) {
                    // If nothing in second artifact slot, use it.
                    access.id = inventory.artifacts[1];
                    access.slot = InventorySlot.artifact1;
                    inventory.artifacts[1] = item_id;
                } else {
                    // Otherwise displace second artifact.
                    access.id = inventory.artifacts[1];
                    access.slot = InventorySlot.artifact1;
                    inventory.artifacts[1] = item_id;
                }
            },
        }

        return access;
    }

    pub fn drop(inventory: *Inventory, item_id: Id, class: ItemClass) InventorySlot {
        switch (class) {
            .primary => {
                inventory.weapon = null;
                return InventorySlot.weapon;
            },

            .consumable => {
                inventory.throwing = null;
                return InventorySlot.throwing;
            },

            .misc => {
                var slot = InventorySlot.artifact0;
                var index: usize = 0;
                if (inventory.artifacts[0] != item_id) {
                    index = 1;
                    slot = InventorySlot.artifact1;
                }
                inventory.artifacts[index] = null;
                return slot;
            },
        }
    }

    pub fn clearSlot(inventory: *Inventory, slot: InventorySlot) void {
        switch (slot) {
            .weapon => inventory.weapon = null,
            .throwing => inventory.throwing = null,
            .artifact0 => inventory.artifacts[0] = null,
            .artifact1 => inventory.artifacts[1] = null,
        }
    }

    pub fn placeSlot(inventory: *Inventory, item_id: Id, slot: InventorySlot) void {
        switch (slot) {
            .weapon => inventory.weapon = item_id,
            .throwing => inventory.throwing = item_id,
            .artifact0 => inventory.artifacts[0] = item_id,
            .artifact1 => inventory.artifacts[1] = item_id,
        }
    }

    /// Check whether there is a open slot for an item of the given class.
    pub fn accessByClass(inventory: *const Inventory, item_class: ItemClass) InventoryAccess {
        var access: InventoryAccess = InventoryAccess{};
        switch (item_class) {
            .primary => {
                access.id = inventory.weapon;
                access.slot = InventorySlot.weapon;
            },

            .consumable => {
                access.id = inventory.throwing;
                access.slot = InventorySlot.throwing;
            },

            .misc => {
                if (inventory.artifacts[0] == null) {
                    // If nothing in first artifact slot, use it.
                    access.id = inventory.artifacts[0];
                    access.slot = InventorySlot.artifact0;
                } else if (inventory.artifacts[1] == null) {
                    // If nothing in second artifact slot, use it.
                    access.id = inventory.artifacts[1];
                    access.slot = InventorySlot.artifact1;
                } else {
                    // Otherwise displace second artifact.
                    access.id = inventory.artifacts[1];
                    access.slot = InventorySlot.artifact1;
                }
            },
        }

        return access;
    }
};
