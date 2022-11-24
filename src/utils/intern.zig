const std = @import("std");
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Str = u64;

/// Simple string intern system.
/// Note that if the same string is inserted multiple times, it is given a new key.
pub const Intern = struct {
    to_key: StringHashMap(Str),
    store: ArrayList([]u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Intern {
        return Intern{
            .to_key = StringHashMap(Str).init(allocator),
            .store = ArrayList([]u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Intern) void {
        self.to_key.deinit();

        while (self.store.popOrNull()) |slice| {
            self.allocator.free(slice);
        }
        self.store.deinit();
    }

    pub fn insert(self: *Intern, str: []const u8) !Str {
        const key = self.store.items.len;
        const new_str = try self.allocator.dupe(u8, str);
        try self.store.append(new_str);
        try self.to_key.put(new_str, key);
        return key;
    }

    pub fn toKey(self: *const Intern, str: []const u8) Str {
        return self.to_key.get(str).?;
    }

    pub fn get(self: *const Intern, str: Str) []const u8 {
        return self.store.items[str];
    }
};

test "intern init deinit" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const allocator = general_purpose_allocator.allocator();

    var intern = Intern.init(allocator);
    defer intern.deinit();
}

test "intern basics" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const allocator = general_purpose_allocator.allocator();

    var intern = Intern.init(allocator);
    defer intern.deinit();

    const key = try intern.insert("test");
    try std.testing.expectEqual(key, intern.toKey("test"));

    const result: []const u8 = intern.get(key);
    try std.testing.expectEqual(@as(u8, 't'), result[0]);
    try std.testing.expectEqual(@as(u8, 'e'), result[1]);
    try std.testing.expectEqual(@as(u8, 's'), result[2]);
    try std.testing.expectEqual(@as(u8, 't'), result[3]);
}
