const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Pos = @import("pos.zig").Pos;

pub const Line = struct {
    step_x: i32 = 0,
    step_y: i32 = 0,
    e: i32 = 0,
    delta_x: i32 = 0,
    delta_y: i32 = 0,
    orig_x: i32 = 0,
    orig_y: i32 = 0,
    dest_x: i32 = 0,
    dest_y: i32 = 0,

    include_start: bool = true,

    pub fn init(start: Pos, end: Pos, include_start: bool) Line {
        var l = Line{};

        l.include_start = include_start;

        l.orig_x = start.x;
        l.orig_y = start.y;

        l.dest_x = end.x;
        l.dest_y = end.y;

        l.delta_x = end.x - start.x;
        l.delta_y = end.y - start.y;

        if (l.delta_x > 0) {
            l.step_x = 1;
        } else if (l.delta_x < 0) {
            l.step_x = -1;
        } else {
            l.step_x = 0;
        }

        if (l.delta_y > 0) {
            l.step_y = 1;
        } else if (l.delta_y < 0) {
            l.step_y = -1;
        } else {
            l.step_y = 0;
        }

        if (l.step_x * l.delta_x > l.step_y * l.delta_y) {
            l.e = l.step_x * l.delta_x;
            l.delta_x *= 2;
            l.delta_y *= 2;
        } else {
            l.e = l.step_y * l.delta_y;
            l.delta_x *= 2;
            l.delta_y *= 2;
        }

        return l;
    }

    pub fn next(self: *Line) ?Pos {
        if (self.include_start) {
            self.include_start = false;
            return Pos.init(self.orig_x, self.orig_y);
        }

        if (self.step_x * self.delta_x > self.step_y * self.delta_y) {
            if (self.orig_x == self.dest_x) {
                return null;
            }

            self.orig_x += self.step_x;

            self.e -= self.step_y * self.delta_y;
            if (self.e < 0) {
                self.orig_y += self.step_y;
                self.e += self.step_x * self.delta_x;
            }
        } else {
            if (self.orig_y == self.dest_y) {
                return null;
            }

            self.orig_y += self.step_y;
            self.e -= self.step_x * self.delta_x;
            if (self.e < 0) {
                self.orig_x += self.step_x;
                self.e += self.step_y * self.delta_y;
            }
        }

        const x: i32 = self.orig_x;
        const y: i32 = self.orig_y;

        return Pos.init(x, y);
    }

    pub fn distance(start: Pos, end: Pos, include_start: bool) i32 {
        var ln = Line.init(start, end, include_start);
        var length: i32 = 0;
        while (ln.next() != null) {
            length += 1;
        }
        return length;
    }

    pub fn mag(self: Pos) i32 {
        return Line.distance(Pos.init(0, 0), self);
    }

    pub fn move_towards(self: Pos, end: Pos, dist: usize) Pos {
        var ln = Line.init(self, end, false);
        var pos = self;
        var index: usize = 0;
        while (ln.next()) |new_pos| {
            index += 1;
            if (index > dist) {
                break;
            }

            pos = new_pos;
        }

        return pos;
    }
};

pub fn makeLine(start: Pos, end: Pos, lineArrayList: *ArrayList(Pos)) !void {
    lineArrayList.clearRetainingCapacity();

    var l = Line.init(start, end, true);

    while (l.next()) |pos| {
        try lineArrayList.append(pos);
    }
}

test "test_lines" {
    const dist: i32 = 10;
    const offset: i32 = dist / 2;

    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var positions = ArrayList(Pos).init(allocator.allocator());

    var x: i32 = 0;
    while (x < dist) : (x += 1) {
        var y: i32 = 0;
        while (y < dist) : (y += 1) {
            const x_offset = x - offset;
            const y_offset = y - offset;
            if (x_offset == 0 and y_offset == 0) {
                continue;
            }

            const start = Pos.init(0, 0);
            const end = Pos.init(x_offset, y_offset);
            try makeLine(start, end, &positions);

            try std.testing.expect(std.meta.eql(positions.items[0], start));
            try std.testing.expect(std.meta.eql(positions.items[positions.items.len - 1], end));
        }
    }
}

test "line distance between positions" {
    const start = Pos.init(0, 0);
    const end = Pos.init(0, 1);

    try std.testing.expectEqual(@intCast(i32, 2), Line.distance(start, end, true));
    try std.testing.expectEqual(@intCast(i32, 1), Line.distance(start, end, false));
}

test "line move towards" {
    const start = Pos.init(0, 0);
    const end = Pos.init(10, 10);
    try std.testing.expectEqual(start, Line.move_towards(start, end, 0));
    try std.testing.expectEqual(Pos.init(5, 5), Line.move_towards(start, end, 5));
    try std.testing.expectEqual(Pos.init(10, 10), Line.move_towards(start, end, 50));
}
