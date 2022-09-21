const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Pos = struct {
    x: i32,
    y: i32,

    pub fn new(x: i32, y: i32) Pos {
        return .{ .x = x, .y = y };
    }
};

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

    pub fn init(start: Pos, end: Pos) Line {
        return Line.new(start, end, true);
    }

    pub fn new(start: Pos, end: Pos, include_start: bool) Line {
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

    pub fn step(self: *Line) ?Pos {
        if (self.include_start) {
            self.include_start = false;
            return Pos.new(self.orig_x, self.orig_y);
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

        return Pos.new(x, y);
    }
};

// Take an arraylist as an argument?
// does not include start position
pub fn makeLine(start: Pos, end: Pos, lineArrayList: *ArrayList(Pos)) !void {
    lineArrayList.clearRetainingCapacity();

    var l = Line.init(start, end);

    while (l.step()) |pos| {
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

            const start = Pos.new(0, 0);
            const end = Pos.new(x_offset, y_offset);
            try makeLine(start, end, &positions);

            try std.testing.expect(std.meta.eql(positions.items[0], start));
            try std.testing.expect(std.meta.eql(positions.items[positions.items.len - 1], end));
        }
    }
}
