const std = @import("std");
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Str = u64;

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
        return self.store.items.get(str).?;
    }
};
