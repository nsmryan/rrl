const std = @import("std");
const PriorityQueue = std.PriorityQueue;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Order = std.math.Order;
const testing = std.testing;

const Pos = @import("math").pos.Pos;

pub const WeighedPos = struct {
    position: Pos,
    weigh: i32,

    pub fn init(position: Pos, weigh: i32) WeighedPos {
        return WeighedPos{ .position = position, .weigh = weigh };
    }
};

pub const Path = struct {
    path: ArrayList(Pos),
    current: Pos,
    cost: i32,

    pub fn init(current: Pos, allocator: Allocator) Path {
        return Path{
            .path = ArrayList(Pos).init(allocator),
            .current = current,
            .cost = 0,
        };
    }

    pub fn deinit(self: Path) void {
        self.path.deinit();
    }

    pub fn dup(self: *Path) !Path {
        var cloned = try self.path.clone();
        return Path{ .path = cloned, .current = self.current, .cost = self.cost };
    }
};

pub const Result = union(enum) {
    done: Path,
    neighbors: Pos,
    no_path,
};

pub fn Astar(comptime distance: fn (Pos, Pos) usize) type {
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
            while (self.next_q.count() > 0) {
                var path = self.next_q.remove();
                path.deinit();
            }
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

        pub fn step(self: *Self, neighbors: []WeighedPos) !Result {
            if (neighbors.len == 0) {
                std.debug.panic("Astar does not work if a tile has no neighbors!", .{});
            }

            if (self.next_q.len == 0) {
                return Result.no_path;
            }

            var best = self.next_q.remove();
            for (neighbors) |neighbor| {
                if (std.meta.eql(neighbor.position, self.end)) {
                    try best.path.append(best.current);
                    try best.path.append(self.end);
                    best.current = self.end;
                    best.cost += 1 + neighbor.weigh;
                    return Result{ .done = best };
                }

                var found: bool = false;
                var i: usize = 0;
                while (i < self.seen.items.len) : (i += 1) {
                    if (std.meta.eql(neighbor.position, self.seen.items[i])) {
                        found = true;
                        break;
                    }
                }
                if (found) {
                    continue;
                }
                try self.seen.append(neighbor.position);

                var new_path = try best.dup();
                try new_path.path.append(best.current);

                new_path.current = neighbor.position;
                new_path.cost += 1 + neighbor.weigh;

                try self.next_q.add(new_path);
            }

            best.deinit();

            const new_best = self.next_q.peek() orelse unreachable;

            return Result{ .neighbors = new_best.current };
        }

        pub fn compare(end: Pos, first: Path, second: Path) Order {
            const firstWeight = first.cost + @intCast(i32, distance(first.current, end));
            const secondWeight = second.cost + @intCast(i32, distance(second.current, end));
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
    //const allocator = std.heap.page_allocator;
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const allocator = general_purpose_allocator.allocator();

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
    var neighbors = ArrayList(WeighedPos).init(allocator);
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
                try neighbors.append(WeighedPos.init(next_pos, 1));
            }
        }

        result = try finder.step(neighbors.items);
    }
    try testing.expectEqual(Result.done, result);
    defer result.done.deinit();

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

    try testing.expectEqual(Pos.init(3, 3), result.done.path.items[6]);

    try testing.expectEqual(Pos.init(4, 4), result.done.current);
}
