const std = @import("std");
const PriorityQueue = std.PriorityQueue;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Order = std.math.Order;
const testing = std.testing;

const Pos = @import("pos.zig").Pos;

pub const Path = struct {
    path: ArrayList(Pos),
    current: Pos,

    pub fn init(current: Pos, allocator: Allocator) Path {
        return Path{
            .path = ArrayList(Pos).init(allocator),
            .current = current,
        };
    }

    pub fn deinit(self: *Path) void {
        self.path.deinit();
    }

    pub fn dup(self: *Path) !Path {
        return Path{ .path = try self.path.clone(), .current = self.current };
    }
};

pub const Result = union(enum) {
    done: Path,
    neighbors: Pos,
    no_path,
};

pub fn Astar(distance: fn (Pos, Pos) usize) type {
    return struct {
        const Self = @This();
        const NextQueue = PriorityQueue(Path, Pos, Self.compare);

        next_q: NextQueue,
        seen: ArrayList(Pos),
        start: Pos,
        end: Pos,
        allocator: Allocator,

        pub fn init(start: Pos, allocator: Allocator) Self {
            return Self{
                .next_q = NextQueue.init(allocator, start),
                .seen = ArrayList(Pos).init(allocator),
                .start = start,
                .end = start,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.next_q.deinit();
            self.seen.deinit();
        }

        pub fn pathFind(self: *Self, start: Pos, end: Pos) !Result {
            self.next_q.len = 0;
            self.seen.items.len = 0;
            try self.seen.append(start);
            self.end = end;
            try self.next_q.add(Path.init(start, self.allocator));

            return Result{ .neighbors = start };
        }

        pub fn step(self: *Self, neighbors: []Pos) !Result {
            if (self.next_q.len == 0) {
                return Result.no_path;
            }

            var best = self.next_q.remove();
            for (neighbors) |neighbor| {
                if (std.meta.eql(neighbor, self.end)) {
                    try best.path.append(self.end);
                    best.current = self.end;
                    return Result{ .done = best };
                }

                var found: bool = false;
                var i: usize = 0;
                while (i < self.seen.items.len) : (i += 1) {
                    if (std.meta.eql(neighbor, self.seen.items[i])) {
                        found = true;
                        break;
                    }
                }
                if (found) {
                    continue;
                }
                try self.seen.append(neighbor);

                var new_path = try best.dup();
                try new_path.path.append(best.current);

                new_path.current = neighbor;
                try self.next_q.add(new_path);
            }

            best.deinit();

            const new_best = self.next_q.peek() orelse unreachable;

            return Result{ .neighbors = new_best.current };
        }

        pub fn compare(end: Pos, first: Path, second: Path) Order {
            const firstWeight = first.path.items.len + distance(first.current, end);
            const secondWeight = second.path.items.len + distance(second.current, end);
            return std.math.order(firstWeight, secondWeight);
        }
    };
}

fn simple_distance(start: Pos, end: Pos) usize {
    const x_dist = std.math.absInt(start.x - end.x) catch unreachable;
    const y_dist = std.math.absInt(start.y - end.y) catch unreachable;
    return @intCast(usize, std.math.min(x_dist, y_dist));
}

const Map = struct {
    blocked: []const []const bool,

    pub fn init(blocked: []const []const bool) Map {
        return Map{ .blocked = blocked };
    }
};

test "pathfinding" {
    const allocator = std.heap.page_allocator;

    const PathFinder = Astar(simple_distance);

    const start = Pos.init(0, 0);
    const end = Pos.init(4, 4);

    var finder = PathFinder.init(start, allocator);
    defer finder.deinit();

    const blocked: [5][]const bool =
        .{
        &.{ false, true, false, false, false },
        &.{ false, true, false, false, false },
        &.{ false, true, false, false, false },
        &.{ false, true, false, false, false },
        &.{ false, false, false, true, false },
    };
    var map = Map.init(blocked[0..]);

    var result = try finder.pathFind(start, end);
    var neighbors = ArrayList(Pos).init(allocator);
    defer neighbors.deinit();

    while (result == .neighbors) {
        const pos = result.neighbors;

        neighbors.clearRetainingCapacity();

        const offsets: [3]i32 = .{ -1, 0, 1 };
        for (offsets) |offset_x| {
            for (offsets) |offset_y| {
                const new_x = pos.x + offset_x;
                const new_y = pos.y + offset_y;
                if ((new_x == pos.x and new_y == pos.y) or new_x < 0 or new_y < 0 or new_x > 4 or new_y > 4) {
                    continue;
                }
                if (map.blocked[@intCast(usize, new_y)][@intCast(usize, new_x)]) {
                    continue;
                }
                const next_pos = Pos.init(new_x, new_y);
                try neighbors.append(next_pos);
            }
        }

        result = try finder.step(neighbors.items);
    }
    try testing.expectEqual(Result.done, result);

    try testing.expectEqual(Pos.init(0, 0), result.done.path.items[0]);
    try testing.expectEqual(Pos.init(0, 1), result.done.path.items[1]);

    try testing.expectEqual(@as(usize, 3), simple_distance(end, result.done.path.items[1]));
    try testing.expectEqual(Pos.init(0, 2), result.done.path.items[2]);

    try testing.expectEqual(@as(usize, 2), simple_distance(end, result.done.path.items[2]));
    try testing.expectEqual(Pos.init(0, 3), result.done.path.items[3]);

    try testing.expectEqual(@as(usize, 1), simple_distance(end, result.done.path.items[3]));
    try testing.expectEqual(Pos.init(1, 4), result.done.path.items[4]);

    try testing.expectEqual(@as(usize, 0), simple_distance(end, result.done.path.items[4]));
    try testing.expectEqual(Pos.init(2, 3), result.done.path.items[5]);

    try testing.expectEqual(Pos.init(4, 4), result.done.current);
}
