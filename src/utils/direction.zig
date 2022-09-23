const std = @import("std");

const Pos = @import("pos.zig").Pos;

const Direction = enum {
    left,
    right,
    up,
    down,
    downLeft,
    downRight,
    upLeft,
    upRight,

    pub fn fromPosition(position: Pos) ?Direction {
        if (position.x == 0 and position.y == 0) {
            return null;
        } else if (position.x == 0 and position.y < 0) {
            return .up;
        } else if (position.x == 0 and position.y > 0) {
            return .down;
        } else if (position.x > 0 and position.y == 0) {
            return .right;
        } else if (position.x < 0 and position.y == 0) {
            return .kleft;
        } else if (position.x > 0 and position.y > 0) {
            return .downRight;
        } else if (position.x > 0 and position.y < 0) {
            return .upRight;
        } else if (position.x < 0 and position.y > 0) {
            return .downLeft;
        } else if (position.x < 0 and position.y < 0) {
            return .upLeft;
        } else {
            std.debug.panic("Direction should not exist for {}", position);
        }
    }

    pub fn fromPositions(start: Pos, end: Pos) Direction {
        const delta = end.sub(start);
        return fromPosition(delta);
    }

    pub fn reverse(self: Direction) Direction {
        return switch (self) {
            .left => .right,
            .right => .left,
            .up => .down,
            .down => .up,
            .downLeft => .upRight,
            .downRight => .upLeft,
            .upLeft => .downRight,
            .upRight => .downLeft,
        };
    }

    pub fn horiz(self: Direction) bool {
        switch (self) {
            .left | .right | .up | .down => return true,
            else => return false,
        }
    }

    pub fn diag(self: Direction) bool {
        return !self.horiz();
    }

    pub fn intoMove(self: Direction) Pos {
        switch (self) {
            .left => Pos.init(-1, 0),
            .right => Pos.init(1, 0),
            .up => Pos.init(0, -1),
            .down => Pos.init(0, 1),
            .downLeft => Pos.init(-1, 1),
            .downRight => Pos.init(1, 1),
            .upLeft => Pos.init(-1, -1),
            .upRight => Pos.init(1, -1),
        }
    }

    pub fn directions() [8]Direction {
        return .{ .left, .right, .up, .down, .downLeft, .downRight, .upLeft, .upRight };
    }

    pub fn fromF32(flt: f32) Direction {
        const index = @floatToInt(usize, flt * 8.0);
        const dirs = Direction.directions();
        return dirs[index];
    }

    pub fn offsetPos(self: Direction, position: Pos, amount: i32) Pos {
        const mov = self.intoMove();
        return position.add(mov.scale(amount));
    }

    pub fn turnAmount(self: Direction, dir: Direction) i32 {
        const dirs = Direction.directions();
        const count = @intCast(i32, dirs.len);

        // These are safe to unpack because 'dirs' contains all directions.
        const start_ix = @intCast(i32, std.mem.indexOfScalar(Direction, dirs[0..], self).?);
        const end_ix = @intCast(i32, std.mem.indexOfScalar(Direction, dirs[0..], dir).?);

        // absInt should always work with these indices.
        const ix_diff = std.math.absInt(end_ix - start_ix) catch unreachable;
        if (ix_diff < 4) {
            return end_ix - start_ix;
        } else if (end_ix > start_ix) {
            return (count - end_ix) + start_ix;
        } else {
            return (count - start_ix) + end_ix;
        }
    }

    pub fn clockwise(self: Direction) Direction {
        switch (self) {
            .left => return .upLeft,
            .right => return .downRight,
            .up => return .upRight,
            .down => return .downLeft,
            .downLeft => return .left,
            .downRight => return .down,
            .upLeft => return .up,
            .upRight => return .right,
        }
    }

    pub fn counterclockwise(self: Direction) Direction {
        switch (self) {
            .left => return .downLeft,
            .right => return .upRight,
            .up => return .upLeft,
            .down => return .downRight,
            .downLeft => return .down,
            .downRight => return .right,
            .upLeft => return .left,
            .upRight => return .up,
        }
    }
};

test "test_direction_turn_amount" {
    try std.testing.expectEqual(@intCast(i32, -1), Direction.up.turnAmount(Direction.upLeft));
    try std.testing.expectEqual(@intCast(i32, 1), Direction.up.turnAmount(Direction.upRight));

    for (Direction.directions()) |dir| {
        try std.testing.expectEqual(@intCast(i32, 0), dir.turnAmount(dir));
    }

    try std.testing.expectEqual(@intCast(i32, 1), Direction.down.turnAmount(Direction.downLeft));
    try std.testing.expectEqual(@intCast(i32, -1), Direction.down.turnAmount(Direction.downRight));

    try std.testing.expectEqual(@intCast(i32, 1), Direction.left.turnAmount(Direction.upLeft));
    try std.testing.expectEqual(@intCast(i32, -1), Direction.left.turnAmount(Direction.downLeft));
}

test "test_direction_clockwise" {
    const dir = Direction.right;

    var index: usize = 0;
    while (index < 8) : (index += 1) {
        const new_dir = dir.clockwise();
        try std.testing.expectEqual(@intCast(i32, 1), dir.turnAmount(new_dir));
    }
    try std.testing.expectEqual(Direction.right, dir);
}

test "test_direction_counterclockwise" {
    const dir = Direction.right;

    var index: usize = 0;
    while (index < 8) : (index += 1) {
        const new_dir = dir.counterclockwise();
        try std.testing.expectEqual(@intCast(i32, -1), dir.turnAmount(new_dir));
    }
    try std.testing.expectEqual(Direction.right, dir);
}
