const std = @import("std");

pub const Pos = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Pos {
        return .{ .x = x, .y = y };
    }

    pub fn moveBy(self: Pos, other: Pos) Pos {
        return Pos.init(self.x + other.x, self.y + other.y);
    }

    pub fn moveX(self: Pos, offset: i32) Pos {
        return Pos.init(self.x + offset, self.y);
    }

    pub fn moveY(self: Pos, offset: i32) Pos {
        return Pos.init(self.x, self.y + offset);
    }

    pub fn sub(self: Pos, other: Pos) Pos {
        return Pos.init(self.x - other.x, self.y - other.y);
    }

    pub fn add(self: Pos, other: Pos) Pos {
        return Pos.init(self.x + other.x, self.y + other.y);
    }

    pub fn scale(self: Pos, scl: i32) Pos {
        return Pos.init(self.x * scl, self.y * scl);
    }

    pub fn valid(self: Pos) bool {
        return self.x >= 0 and self.y >= 0;
    }

    pub fn randFromPos(self: Pos) f32 {
        var hasher = std.hash.Wyhash.init(1);
        std.hash.autoHash(&hasher, self.x);
        std.hash.autoHash(&hasher, self.y);
        const result = hasher.final();
        return @intToFloat(f32, result & 0xFFFFFFFF) / 4294967295.0;
    }

    pub fn distanceTiles(self: Pos, other: Pos) i32 {
        const dist_x = std.math.absInt(self.x - other.x) catch {
            @panic("Overflow in abs!");
        };
        const dist_y = std.math.absInt(self.y - other.y) catch {
            @panic("Overflow in abs!");
        };
        return dist_x + dist_y;
    }

    pub fn distanceMaximum(self: Pos, other: Pos) i32 {
        const dist_x = std.math.absInt(self.x - other.x) catch {
            @panic("Overflow in abs!");
        };
        const dist_y = std.math.absInt(self.y - other.y) catch {
            @panic("Overflow in abs!");
        };
        return std.math.max(dist_x, dist_y);
    }

    pub fn distance(self: Pos, other: Pos) f32 {
        const x_dist = @intToFloat(f32, self.x - other.x);
        const y_dist = @intToFloat(f32, self.y - other.y);
        return std.math.fabs(std.math.sqrt(x_dist * x_dist + y_dist * y_dist));
    }

    pub fn mag(self: Pos) i32 {
        return self.distanceMaximum(Pos.init(0, 0));
    }

    pub fn mirrorInX(self: Pos, width: i32) Pos {
        return Pos.init(width - self.x - 1, self.y);
    }

    pub fn mirrorInY(self: Pos, height: i32) Pos {
        return Pos.init(self.x, height - self.y - 1);
    }

    pub fn inDirectionOf(self: Pos, other: Pos) Pos {
        const dpos = other.sub(self);
        const dx = std.math.sign(dpos.x);
        const dy = std.math.sign(dpos.y);
        return self.add(Pos.init(dx, dy));
    }

    pub fn isOrdinal(self: Pos) bool {
        return (self.x == 0 and self.y != 0) or (self.y == 0 and self.x != 0);
    }

    pub fn stepTowards(self: Pos, target: Pos) Pos {
        const dx = target.x - self.x;
        const dy = target.y - self.y;
        const delta = Pos.init(std.math.sign(dx), std.math.sign(dy));
        return delta;
    }

    pub fn onePassedDelta(self: Pos, delta: Pos) Pos {
        var next_pos = self.add(delta);

        if (delta.x != 0) {
            next_pos.x += std.math.sign(delta.x);
        }

        if (delta.y != 0) {
            next_pos.y += std.math.sign(delta.y);
        }

        return next_pos;
    }

    pub fn onePassedPos(self: Pos, end: Pos) Pos {
        const diff = end.sub(self);
        return self.onePassedDelta(diff);
    }

    pub fn dot(self: Pos, other: Pos) i32 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn eql(self: Pos, other: Pos) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn nextPos(pos: Pos, delta_pos: Pos) Pos {
        var next_pos = pos.add(delta_pos);

        if (delta_pos.x != 0) {
            next_pos.x += std.math.sign(delta_pos.x);
        }

        if (delta_pos.y != 0) {
            next_pos.y += std.math.sign(delta_pos.y);
        }

        return next_pos;
    }
};

test "test in direction of" {
    const start = Pos.init(1, 1);

    try std.testing.expectEqual(Pos.init(0, 0), start.inDirectionOf(Pos.init(0, 0)));
    try std.testing.expectEqual(Pos.init(2, 2), start.inDirectionOf(Pos.init(10, 10)));
    try std.testing.expectEqual(Pos.init(2, 1), start.inDirectionOf(Pos.init(10, 1)));
    try std.testing.expectEqual(Pos.init(1, 2), start.inDirectionOf(Pos.init(1, 10)));
    try std.testing.expectEqual(Pos.init(1, 0), start.inDirectionOf(Pos.init(1, -10)));
    try std.testing.expectEqual(Pos.init(0, 1), start.inDirectionOf(Pos.init(-10, 1)));
    try std.testing.expectEqual(Pos.init(0, 0), start.inDirectionOf(Pos.init(-10, -10)));
}

test "one passed pos" {
    try std.testing.expectEqual(Pos.init(3, 3), Pos.init(1, 1).onePassedPos(Pos.init(2, 2)));
    try std.testing.expectEqual(Pos.init(1, 3), Pos.init(1, 1).onePassedPos(Pos.init(1, 2)));
}

test "one passed delta" {
    try std.testing.expectEqual(Pos.init(2, 2), Pos.init(0, 0).onePassedDelta(Pos.init(1, 1)));
    try std.testing.expectEqual(Pos.init(0, 2), Pos.init(0, 0).onePassedDelta(Pos.init(0, 1)));
    try std.testing.expectEqual(Pos.init(0, -2), Pos.init(0, 0).onePassedDelta(Pos.init(0, -1)));
    try std.testing.expectEqual(Pos.init(-2, 0), Pos.init(0, 0).onePassedDelta(Pos.init(-1, 0)));
}
