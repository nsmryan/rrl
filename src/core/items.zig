const std = @import("std");

const entities = @import("entities.zig");
const EntityName = entities.EntityName;
const Config = @import("config.zig").config.Config;

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
        switch (item) {
            .stone => config.stun_turns_throw_stone,
            .spear => config.stun_turns_throw_spear,
            else => config.stun_turns_throw_default,
        }
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

pub const InventoryDropped = struct {
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

    pub fn addItem(inventory: *Inventory, item_id: Id, class: ItemClass) InventoryDropped {
        var dropped: InventoryDropped = InventoryDropped{};
        switch (class) {
            .primary => {
                dropped.id = inventory.weapon;
                dropped.slot = InventorySlot.weapon;
                inventory.weapon = item_id;
            },

            .consumable => {
                dropped.id = inventory.throwing;
                dropped.slot = InventorySlot.throwing;
                inventory.throwing = item_id;
            },

            .misc => {
                if (inventory.artifacts[0] == null) {
                    // If nothing in first artifact slot, use it.
                    dropped.id = inventory.artifacts[0];
                    dropped.slot = InventorySlot.artifact0;
                    inventory.artifacts[0] = item_id;
                } else if (inventory.artifacts[1] == null) {
                    // If nothing in second artifact slot, use it.
                    dropped.id = inventory.artifacts[1];
                    dropped.slot = InventorySlot.artifact1;
                    inventory.artifacts[1] = item_id;
                } else {
                    // Otherwise displace second artifact.
                    dropped.id = inventory.artifacts[1];
                    dropped.slot = InventorySlot.artifact1;
                    inventory.artifacts[1] = item_id;
                }
            },
        }

        return dropped;
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
    pub fn classAvailable(inventory: *const Inventory, item_class: ItemClass) bool {
        switch (item_class) {
            .primary => return inventory.weapon == null,
            .consumable => return inventory.throwing == null,
            .misc => return inventory.artifacts[0] == null or inventory.artifacts[1] == null,
        }
    }
};
