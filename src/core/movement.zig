const std = @import("std");
const print = std.debug.print;
const BoundedArray = std.BoundedArray;

const board = @import("board");
const Height = board.tile.Tile.Height;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const Line = math.line.Line;

const utils = @import("utils");
const Id = utils.comp.Id;

pub const HitWall = struct {
    height: Height,
    blocked_tile: bool,

    pub fn init(height: Height, blocked_tile: bool) HitWall {
        return HitWall{ .height = height, .blocked_tile = blocked_tile };
    }
};

pub const Collision = struct {
    entity: ?Id = null,
    wall: ?HitWall = null,
    pos: Pos = Pos.init(0, 0),
    dir: Direction = Direction.left,

    pub fn init(pos: Pos, dir: Direction) Collision {
        return Collision{ .pos = pos, .dir = dir };
    }

    pub fn hit(collision: Collision) bool {
        return collision.entity != null or collision.wall != null;
    }

    pub fn onlyHitEntity(collision: Collision) bool {
        return collision.entity != null and collision.wall == null;
    }

    pub fn onlyHitWall(collision: Collision) bool {
        return collision.entity == null and collision.wall != null;
    }
};

pub const Attack = union(enum) {
    attack: Id, // target_id
    push: struct { id: Id, dir: Direction, amount: usize }, //target_id, direction, amount
    stab: struct { id: Id, move_into_space: bool }, // target_id, move into space
};

pub const AttackType = enum {
    melee,
    ranged,
    push,
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

    pub fn single(dist: usize) Reach {
        return Reach{ .single = dist };
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

    pub fn reachLineInDirection(self: Reach, move_pos: Pos, move_action: Direction) ?Line {
        if (self.moveWithReach(move_action)) |pos| {
            return Line.init(move_pos, move_pos.add(pos), true);
        }
        return null;
    }

    pub fn moveWithReach(self: Reach, move_action: Direction) ?Pos {
        switch (self) {
            .single => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                const neg_dist = dist * -1;
                switch (move_action) {
                    .left => return Pos.init(neg_dist, 0),
                    .right => return Pos.init(dist, 0),
                    .up => return Pos.init(0, neg_dist),
                    .down => return Pos.init(0, dist),
                    .downLeft => return Pos.init(neg_dist, dist),
                    .downRight => return Pos.init(dist, dist),
                    .upLeft => return Pos.init(neg_dist, neg_dist),
                    .upRight => return Pos.init(dist, neg_dist),
                }
            },

            .diag => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                const neg_dist = dist * -1;
                switch (move_action) {
                    .left => return null,
                    .right => return null,
                    .up => return null,
                    .down => return null,
                    .downLeft => return Pos.init(neg_dist, dist),
                    .downRight => return Pos.init(dist, dist),
                    .upLeft => return Pos.init(neg_dist, neg_dist),
                    .upRight => return Pos.init(dist, neg_dist),
                }
            },

            .horiz => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                const neg_dist = dist * -1;
                switch (move_action) {
                    .left => return Pos.init(neg_dist, 0),
                    .right => return Pos.init(dist, 0),
                    .up => return Pos.init(0, neg_dist),
                    .down => return Pos.init(0, dist),
                    .downLeft => return null,
                    .downRight => return null,
                    .upLeft => return null,
                    .upRight => return null,
                }
            },
        }
    }

    pub fn reachables(self: Reach, start: Pos) !BoundedArray(Pos, 8) {
        const offs = try self.offsets();

        var reachable = try BoundedArray(Pos, 8).init(0);
        for (offs.constSlice()) |offset| {
            try reachable.append(start.add(offset));
        }

        return reachable;
    }

    pub fn offsets(self: Reach) !BoundedArray(Pos, 8) {
        var end_points: BoundedArray(Pos, 8) = try BoundedArray(Pos, 8).init(0);

        switch (self) {
            .single => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                try end_points.append(Pos.init(0, dist));
                try end_points.append(Pos.init(-dist, dist));
                try end_points.append(Pos.init(-dist, 0));
                try end_points.append(Pos.init(-dist, -dist));
                try end_points.append(Pos.init(0, -dist));
                try end_points.append(Pos.init(dist, -dist));
                try end_points.append(Pos.init(dist, 0));
                try end_points.append(Pos.init(dist, dist));
            },

            .horiz => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                try end_points.append(Pos.init(dist, 0));
                try end_points.append(Pos.init(0, dist));
                try end_points.append(Pos.init(-1 * dist, 0));
                try end_points.append(Pos.init(0, -1 * dist));
            },

            .diag => |reach_dist| {
                const dist = @intCast(i32, reach_dist);
                try end_points.append(Pos.init(dist, dist));
                try end_points.append(Pos.init(-1 * dist, dist));
                try end_points.append(Pos.init(dist, -1 * dist));
                try end_points.append(Pos.init(-1 * dist, -1 * dist));
            },
        }

        return end_points;
    }
};

test "test reach offsets horiz" {
    const horiz = Reach.horiz(1);
    const offsets = try horiz.offsets();

    const expected_pos = [_]Pos{ Pos.init(1, 0), Pos.init(-1, 0), Pos.init(0, 1), Pos.init(0, -1) };
    for (expected_pos) |first| {
        var found = false;
        for (offsets.buffer) |second| {
            found = found or first.eql(second);
        }
        std.debug.assert(found);
    }
    try std.testing.expectEqual(expected_pos.len, offsets.len);
}

test "test reach offsets diag" {
    const diag = Reach.diag(1);
    const offsets = try diag.offsets();

    const expected_pos = [_]Pos{ Pos.init(-1, -1), Pos.init(1, -1), Pos.init(-1, 1), Pos.init(1, 1) };
    for (expected_pos) |first| {
        var found = false;
        for (offsets.buffer) |second| {
            found = found or first.eql(second);
        }
        std.debug.assert(found);
    }
    try std.testing.expectEqual(expected_pos.len, offsets.len);
}

test "test reach offsets single" {
    const single = Reach.single(1);
    const offsets = try single.offsets();

    const expected_pos = [_]Pos{ Pos.init(1, 0), Pos.init(0, 1), Pos.init(-1, 0), Pos.init(0, -1), Pos.init(1, 1), Pos.init(-1, 1), Pos.init(1, -1), Pos.init(-1, -1) };
    for (expected_pos) |first| {
        var found = false;
        for (offsets.buffer) |second| {
            found = found or first.eql(second);
        }
        std.debug.assert(found);
    }
    try std.testing.expectEqual(expected_pos.len, offsets.len);
}

test "test reach reachables single" {
    const single = Reach.single(1);
    const offsets = try single.offsets();
    try std.testing.expectEqual(@as(usize, 8), offsets.len);

    const positions = try single.reachables(Pos.init(5, 5));
    try std.testing.expectEqual(@as(usize, 8), positions.len);
}

test "test reach reachables diag" {
    const diag = Reach.diag(5);
    const offsets = try diag.offsets();
    try std.testing.expectEqual(@as(usize, 4), offsets.len);

    const positions = try diag.reachables(Pos.init(5, 5));
    try std.testing.expectEqual(@as(usize, 4), positions.len);
}
