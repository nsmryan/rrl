const std = @import("std");

pub const Pos = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Pos {
        return .{ .x = x, .y = y };
    }

    pub fn move_by(self: Pos, other: Pos) Pos {
        return Pos.init(self.x + other.x, self.y + other.y);
    }

    pub fn move_x(self: Pos, offset: i32) Pos {
        return Pos.init(self.x + offset, self.y);
    }

    pub fn move_y(self: Pos, offset: i32) Pos {
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

    pub fn rand_from_pos(self: Pos) f32 {
        var hasher = std.hash.Wyhash.init(1);
        std.hash.auto_hash(&hasher, self.x);
        std.hash.auto_hash(&hasher, self.y);
        const result = hasher.final();
        return @intToFloat(f32, result & 0xFFFFFFFF) / 4294967295.0;
    }

    pub fn distance_tiles(self: Pos, other: Pos) i32 {
        return std.math.intAbs(self.x - other.x) + std.math.intAbs(self.y - other.y);
    }

    pub fn distance_maximum(self: Pos, other: Pos) i32 {
        return std.math.max(std.math.intAbs(self.x - other.x), std.math.intAbs(self.y - other.y));
    }

    pub fn mirror_in_x(self: Pos, width: i32) Pos {
        return Pos.init(width - self.x - 1, self.y);
    }

    pub fn mirror_in_y(self: Pos, height: i32) Pos {
        return Pos.init(self.x, height - self.y - 1);
    }

    pub fn in_direction_of(self: Pos, other: Pos) Pos {
        const dpos = other.sub(self);
        const dx = std.math.sign(dpos.x);
        const dy = std.math.sign(dpos.y);
        return self.add(Pos.init(dx, dy));
    }
};
