const std = @import("std");
const ArrayList = std.ArrayList;

const board = @import("board");
const Height = board.tile.Tile.Height;

const Array = @import("utils").buffer.Array;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const Line = math.line.Line;

pub const HitWall = struct {
    height: Height,
    blocked_tile: bool,

    pub fn init(height: Height, blocked_tile: bool) HitWall {
        return HitWall{ .height = height, .blocked_tile = blocked_tile };
    }
};

pub const Collision = struct {
    entity: bool = false,
    wall: ?HitWall = null,
    pos: Pos = Pos.init(0, 0),
    dir: Direction = Direction.left,

    pub fn init(pos: Pos, dir: Direction) Collision {
        return Collision{ .pos = pos, .dir = dir };
    }

    pub fn hit(collision: Collision) bool {
        return collision.entity or collision.wall != null;
    }
};

pub const MoveMode = enum {
    sneak,
    walk,
    run,

    pub fn increase(self: MoveMode) MoveMode {
        switch (self) {
            MoveMode.sneak => MoveMode.walk,
            MoveMode.run => MoveMode.run,
            MoveMode.walk => MoveMode.run,
        }
    }

    pub fn decrease(self: MoveMode) MoveMode {
        switch (self) {
            MoveMode.sneak => MoveMode.sneak,
            MoveMode.run => MoveMode.walk,
            MoveMode.walk => MoveMode.sneak,
        }
    }

    pub fn moveAmount(self: MoveMode) usize {
        return switch (self) {
            .sneak => 1,
            .walk => 1,
            .run => 2,
        };
    }
};

pub const MoveType = enum {
    move,
    pass,
    jumpWall,
    blink,
    misc,
};

pub const Reach = union(enum) {
    single: usize,
    diag: usize,
    horiz: usize,

    pub fn new() Reach {
        return Reach{ .single = 1 };
    }

    pub fn single(dist: usize) Reach {
        return Reach.single(dist);
    }

    pub fn diag(dist: usize) Reach {
        return Reach{ .diag = dist };
    }

    pub fn horiz(dist: usize) Reach {
        return Reach{ .horiz = dist };
    }

    pub fn distance(self: Reach) usize {
        switch (self) {
            .single => |dist| return dist,
            .diag => |dist| return dist,
            .horiz => |dist| return dist,
        }
    }

    pub fn withDist(self: Reach, dist: usize) Reach {
        switch (self) {
            .single => .single(dist),
            .diag => .diag(dist),
            .horiz => .horiz(dist),
        }
    }

    pub fn furthestInDirection(self: Reach, pos: Pos, dir: Direction) ?Pos {
        const valid =
            switch (self) {
            .diag => dir.diag(),
            .horiz => dir.horiz(),
            .single => true,
        };

        if (valid) {
            return dir.offsetPos(pos, @intCast(i32, self.dist()));
        } else {
            return null;
        }
    }

    pub fn closestTo(self: Reach, pos: Pos, other: Pos) Pos {
        const offs = self.offsets();

        var closest: Pos = offs.get(0).?;

        for (offs) |offset| {
            const other_pos = pos.add(offset);
            if (distance(other, other_pos) < distance(other, closest)) {
                closest = other_pos;
            }
        }

        return closest;
    }

    pub fn attacksWithReach(self: Reach, move_action: Direction, positions: *ArrayList(Pos)) !void {
        if (self.move_with_reach(move_action)) |pos| {
            for (Line.init(Pos.init(0, 0), pos, true)) |line_pos| {
                try positions.push(line_pos);
            }
        }
    }

    pub fn moveWithReach(self: Reach, move_action: Direction) ?Pos {
        switch (self) {
            .single => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                const neg_dist = dist * -1;
                switch (move_action) {
                    .left => Pos.init(neg_dist, 0),
                    .right => Pos.init(dist, 0),
                    .up => Pos.init(0, neg_dist),
                    .down => Pos.init(0, dist),
                    .downLeft => Pos.init(neg_dist, dist),
                    .downRight => Pos.init(dist, dist),
                    .upLeft => Pos.init(neg_dist, neg_dist),
                    .upRight => Pos.init(dist, neg_dist),
                }
            },

            .diag => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                const neg_dist = dist * -1;
                switch (move_action) {
                    .left => null,
                    .right => null,
                    .up => null,
                    .down => null,
                    .downLeft => Pos.init(neg_dist, dist),
                    .downRight => Pos.init(dist, dist),
                    .upLeft => Pos.init(neg_dist, neg_dist),
                    .upRight => Pos.init(dist, neg_dist),
                }
            },

            .horiz => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                const neg_dist = dist * -1;
                switch (move_action) {
                    .left => Pos.init(neg_dist, 0),
                    .right => Pos.init(dist, 0),
                    .up => Pos.init(0, neg_dist),
                    .down => Pos.init(0, dist),
                    .downLeft => null,
                    .downRight => null,
                    .upLeft => null,
                    .upRight => null,
                }
            },
        }
    }

    pub fn reachables(self: Reach, start: Pos) !Array(Pos, 8) {
        const offs = self.offsets();

        var reachable: Array(Pos, 8) = Array(Pos, 8).init();
        for (offs.mem) |offset| {
            try reachable.push(start.add(offset));
        }

        return reachable;
    }

    pub fn offsets(self: Reach) !Array(Pos, 8) {
        const end_points: Array(Pos, 8) = Array(Pos, 8).init();

        switch (self) {
            .single => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                try end_points.push(Pos.init(0, dist));
                try end_points.push(Pos.init(-dist, dist));
                try end_points.push(Pos.init(-dist, 0));
                try end_points.push(Pos.init(-dist, -dist));
                try end_points.push(Pos.init(0, -dist));
                try end_points.push(Pos.init(dist, -dist));
                try end_points.push(Pos.init(dist, 0));
                try end_points.push(Pos.init(dist, dist));
            },

            .horiz => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                var index: usize = 1;
                while (index <= dist) {
                    try end_points.push(Pos.init(dist, 0));
                    try end_points.push(Pos.init(0, dist));
                    try end_points.push(Pos.init(-1 * dist, 0));
                    try end_points.push(Pos.init(0, -1 * dist));
                }
            },

            .diag => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                var index: usize = 1;
                while (index <= dist) {
                    try end_points.push(Pos.init(dist, dist));
                    try end_points.push(Pos.init(-1 * dist, dist));
                    try end_points.push(Pos.init(dist, -1 * dist));
                    try end_points.push(Pos.init(-1 * dist, -1 * dist));
                }
            },
        }

        var offs = Array(Pos, 8).init();
        for (end_points.mem) |end| {
            var line = Line.init(Pos.init(0, 0), end, true);
            while (line.next()) |pos| {
                if (!offs.contains(pos)) {
                    try offs.push(pos);
                }
            }
        }

        return offsets;
    }
};

test "test reach offsets horiz" {
    const horiz = Reach.horiz(1);
    const offsets = horiz.offsets();

    const expected_pos = [_]Pos{ Pos.init(1, 0), Pos.init(-1, 0), Pos.init(0, 1), Pos.init(0, -1) };
    for (offsets.mem) |pos| {
        var found = false;
        for (expected_pos.mem) |other| {
            if (pos.eql(other)) {
                found = true;
                break;
            }
        }
        std.debug.assert(found);
    }
}

test "test reach offsets diag" {
    const horiz = Reach.diag(1);
    const offsets = horiz.offsets();

    const expected_pos = [_]Pos{ Pos.init(-1, -1), Pos.init(-1, -1), Pos.init(-1, -1), Pos.init(-1, -1) };
    for (offsets.mem) |pos| {
        var found = false;
        for (expected_pos.mem) |other| {
            if (pos.eql(other)) {
                found = true;
                break;
            }
        }
        std.debug.assert(found);
    }
}

test "test reach offsets single" {
    const horiz = Reach.single(1);
    const offsets = horiz.offsets();

    const expected_pos = [_]Pos{ Pos.init(1, 0), Pos.init(0, 1), Pos.init(-1, 0), Pos.init(0, -1), Pos.init(1, 1), Pos.init(-1, 1), Pos.init(1, -1), Pos.init(-1, -1) };

    for (offsets.mem) |pos| {
        var found = false;
        for (expected_pos.mem) |other| {
            if (pos.eql(other)) {
                found = true;
                break;
            }
        }
        std.debug.assert(found);
    }
}

test "test reach reachables" {
    const single = Reach.single(1);
    const offsets = single.offsets();
    std.debug.assert(8, offsets.mem.len);

    const positions = single.reachables(Pos.init(5, 5));
    std.debug.assert(8, positions.mem.len);
}
