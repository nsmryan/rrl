const std = @import("std");

const math = std.math;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Id = u64;

pub fn main() anyerror!void {
    std.log.info("rustrl", .{});
}

fn Comp(comptime T: type) type {
    return struct {
        ids: ArrayList(Id),
        store: ArrayList(T),

        const Self = @This();

        fn init(allocator: Allocator) Comp(T) {
            var ids = ArrayList(Id).init(allocator);
            var store = ArrayList(T).init(allocator);
            return Self{ .ids = ids, .store = store };
        }

        fn clear(self: *Self) void {
            self.ids.clear();
            self.store.clear();
        }

        fn insert(self: *Self, id: Id, data: T) !void {
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

        fn remove(self: *Self, id: Id) void {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| {
                    _ = self.store.orderedRemove(loc);
                    _ = self.ids.orderedRemove(loc);
                },

                .not_found => {},
            }
        }

        fn len(self: *Self) usize {
            return self.ids.items.len;
        }

        fn lookup(self: *Self, id: Id) ?usize {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| return loc,
                .not_found => return null,
            }
        }

        fn get(self: *Self, id: Id) ?T {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| return self.store.items[loc],
                .not_found => return null,
            }
        }

        fn get_ptr(self: *Self, id: Id) ?*T {
            switch (binarySearchKeys(id, self.ids.items)) {
                .found => |loc| return &self.store.items[loc],
                .not_found => return null,
            }
        }

        fn contains_key(self: *Self, id: Id) bool {
            return self.lookup(id) != null;
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
    var allocator = std.heap.page_allocator;
    var comp = Comp(u64).init(allocator);
    _ = comp;
}

test "remove from comp" {
    var allocator = std.heap.page_allocator;
    var comp = Comp(u64).init(allocator);
    try comp.insert(0, 1);
    try comp.insert(1, 1);
    try comp.insert(2, 1);
    comp.remove(0);
    try std.testing.expectEqual(@intCast(usize, 2), comp.len());
    comp.remove(1);
    try std.testing.expectEqual(@intCast(usize, 1), comp.len());
    comp.remove(2);
    try std.testing.expectEqual(@intCast(usize, 0), comp.len());
}

test "lookup key from comp" {
    var allocator = std.heap.page_allocator;
    var comp = Comp(u64).init(allocator);
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
    var allocator = std.heap.page_allocator;
    var comp = Comp(u64).init(allocator);

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

test "comp get_ptr" {
    var allocator = std.heap.page_allocator;
    var comp = Comp(u64).init(allocator);

    try comp.insert(0, 10);
    try comp.insert(1, 11);
    try comp.insert(2, 12);

    var value: u64 = 0;

    value = 10;
    var ptr = comp.get_ptr(0).?;
    try std.testing.expectEqual(value, ptr.*);

    // Test that we can modify the pointer and change the item in the Comp's storage.
    ptr.* = 100;
    value = 100;
    try std.testing.expectEqual(value, comp.get_ptr(0).?.*);

    value = 11;
    try std.testing.expectEqual(value, comp.get_ptr(1).?.*);

    value = 12;
    try std.testing.expectEqual(value, comp.get_ptr(2).?.*);

    var null_value: ?*usize = null;
    try std.testing.expectEqual(null_value, comp.get_ptr(3));
}

test "comp contains key" {
    var allocator = std.heap.page_allocator;
    var comp = Comp(u64).init(allocator);

    try comp.insert(0, 10);

    try std.testing.expect(comp.contains_key(0));
    try std.testing.expect(!comp.contains_key(1));
}
