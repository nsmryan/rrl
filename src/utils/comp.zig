const std = @import("std");

const math = std.math;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Id = u64;

pub fn Comp(comptime T: type) type {
    return struct {
        ids: ArrayList(Id),
        store: ArrayList(T),

        const Self = @This();

        pub fn init(allocator: Allocator) Comp(T) {
            var ids = ArrayList(Id).init(allocator);
            var store = ArrayList(T).init(allocator);
            return Self{ .ids = ids, .store = store };
        }

        pub fn deinit(self: *Self) void {
            self.ids.deinit();

            if ((@typeInfo(T) == .Struct or @typeInfo(T) == .Union) and @hasDecl(T, "deinit")) {
                while (self.store.popOrNull()) |item| {
                    var value = item;
                    value.deinit();
                }
            }
            self.store.deinit();
        }

        pub fn clear(self: *Self) void {
            self.ids.clearRetainingCapacity();
            self.store.clearRetainingCapacity();
        }

        pub fn insert(self: *Self, id: Id, data: T) !void {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| {
                    self.store.items[loc] = data;
                },

                .not_found => |loc| {
                    try self.ids.insert(loc, id);
                    try self.store.insert(loc, data);
                },
            }
        }

        pub fn remove(self: *Self, id: Id) void {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| {
                    _ = self.store.orderedRemove(loc);
                    _ = self.ids.orderedRemove(loc);
                },

                .not_found => {},
            }
        }

        pub fn len(self: *Self) usize {
            return self.ids.items.len;
        }

        pub fn lookup(self: *Self, id: Id) ?usize {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| return loc,
                .not_found => return null,
            }
        }

        pub fn get(self: *Self, id: Id) ?T {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| return self.store.items[loc],
                .not_found => return null,
            }
        }

        pub fn has(self: *Self, id: Id) bool {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => return true,
                .not_found => return false,
            }
        }

        pub fn getPtr(self: *Self, id: Id) ?*T {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| return &self.store.items[loc],
                .not_found => return null,
            }
        }

        pub fn set(self: *Self, id: Id, t: T) void {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| self.store.items[loc] = t,
                .not_found => return,
            }
        }

        pub fn contains_key(self: *Self, id: Id) bool {
            return self.lookup(id) != null;
        }

        pub fn iter(self: *Self) CompIterator(T) {
            return CompIterator(T){ .ix = 0, .comp = self };
        }
    };
}

pub fn CompIterator(comptime T: type) type {
    return struct {
        ix: usize,
        comp: *Comp(T),

        const Self = @This();

        pub fn next(self: *Self) ?T {
            if (self.ix < self.comp.ids.items.len) {
                const ix = self.ix;
                self.ix += 1;
                return self.comp.store.items[ix];
            }
            return null;
        }
    };
}

const SearchResult = union(enum) {
    found: usize,
    not_found: usize,
};

fn binarySearchKeys(key: Id, items: []const Id) SearchResult {
    var left: usize = 0;
    var right: usize = items.len;

    while (left < right) {
        // Avoid overflowing in the midpoint calculation
        const mid = left + (right - left) / 2;
        // Compare the key with the midpoint element
        switch (math.order(key, items[mid])) {
            .eq => return SearchResult{ .found = mid },
            .gt => left = mid + 1,
            .lt => right = mid,
        }
    }

    return SearchResult{ .not_found = left };
}

test "binary search location found" {
    const items = [_]Id{ 0, 1, 2, 3 };

    const loc = binarySearchKeys(1, items[0..]);
    const expected = SearchResult{ .found = 1 };
    try std.testing.expectEqual(expected, loc);
}

test "binary search location missing" {
    const items = [_]Id{ 0, 2, 3 };

    const loc = binarySearchKeys(1, items[0..]);
    const expected = SearchResult{ .not_found = 1 };
    try std.testing.expectEqual(expected, loc);
}

test "binary search location missing end" {
    const items = [_]Id{ 0, 2, 3 };

    const loc = binarySearchKeys(10, items[0..]);
    const expected = SearchResult{ .not_found = 3 };
    try std.testing.expectEqual(expected, loc);
}

test "make comp" {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var comp = Comp(u64).init(allocator.allocator());
    _ = comp;
}

test "remove from comp" {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var comp = Comp(u64).init(allocator.allocator());
    try comp.insert(0, 1);
    try comp.insert(1, 1);
    try comp.insert(2, 1);
    comp.remove(0);
    try std.testing.expectEqual(@as(usize, 2), comp.len());
    comp.remove(1);
    try std.testing.expectEqual(@as(usize, 1), comp.len());
    comp.remove(2);
    try std.testing.expectEqual(@as(usize, 0), comp.len());
}

test "lookup key from comp" {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var comp = Comp(u64).init(allocator.allocator());
    try comp.insert(0, 1);
    try comp.insert(1, 1);
    try comp.insert(2, 1);

    const not_found: ?usize = null;
    try std.testing.expectEqual(not_found, comp.lookup(10));

    var ix: ?usize = null;

    ix = 0;
    try std.testing.expectEqual(ix, comp.lookup(0));

    ix = 1;
    try std.testing.expectEqual(ix, comp.lookup(1));

    ix = 2;
    try std.testing.expectEqual(ix, comp.lookup(2));
}

test "comp get" {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var comp = Comp(u64).init(allocator.allocator());

    try comp.insert(0, 10);
    try comp.insert(1, 11);
    try comp.insert(2, 12);

    var value: ?u64 = null;

    value = 10;
    try std.testing.expectEqual(value, comp.get(0));

    value = 11;
    try std.testing.expectEqual(value, comp.get(1));

    value = 12;
    try std.testing.expectEqual(value, comp.get(2));

    value = null;
    try std.testing.expectEqual(value, comp.get(3));
}

test "comp getPtr" {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var comp = Comp(u64).init(allocator.allocator());

    try comp.insert(0, 10);
    try comp.insert(1, 11);
    try comp.insert(2, 12);

    var value: u64 = 0;

    value = 10;
    var ptr = comp.getPtr(0).?;
    try std.testing.expectEqual(value, ptr.*);

    // Test that we can modify the pointer and change the item in the Comp's storage.
    ptr.* = 100;
    value = 100;
    try std.testing.expectEqual(value, comp.getPtr(0).?.*);

    value = 11;
    try std.testing.expectEqual(value, comp.getPtr(1).?.*);

    value = 12;
    try std.testing.expectEqual(value, comp.getPtr(2).?.*);

    var null_value: ?*usize = null;
    try std.testing.expectEqual(null_value, comp.getPtr(3));
}

test "comp contains key" {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var comp = Comp(u64).init(allocator.allocator());

    try comp.insert(0, 10);

    try std.testing.expect(comp.contains_key(0));
    try std.testing.expect(!comp.contains_key(1));
}

test "comp iterator" {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var comp = Comp(u64).init(allocator.allocator());

    try comp.insert(0, 10);
    try comp.insert(1, 11);
    try comp.insert(2, 12);

    var iter = comp.iter();
    try std.testing.expectEqual(@as(usize, 10), iter.next().?);
    try std.testing.expectEqual(@as(usize, 11), iter.next().?);
    try std.testing.expectEqual(@as(usize, 12), iter.next().?);

    // This causes a compiler bug:
    //const null_value: ?usize = null;
    //try std.testing.expectEqual(null_value, iter.next());

    // This also causes a compiler bug:
    //try std.testing.expectEqual(@as(?usize, null), iter.next());

    try std.testing.expectEqual(@as(usize, 0), iter.next() orelse 0);
}
