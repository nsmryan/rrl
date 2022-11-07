const board = @import("board");
const Height = board.tile.Tile.Height;

const core = @import("core");
const Pos = core.pos.Pos;
const Direction = core.direction.Direction;

pub const HitWall = struct {
    height: Height,
    blocked_tile: bool,

    pub fn init(height: Height, blocked_tile: bool) HitWall {
        return HitWall{ .height = height, .blocked_tile = blocked_tile };
    }
};

pub const Collision = struct {
    entity: bool,
    wall: ?HitWall,
    pos: Pos,
    dir: Direction,

    pub fn init(pos: Pos, dir: Direction) Collision {
        return Collision{ .id = null, .wall = null, .pos = pos, .dir = dir };
    }

    pub fn hit(collision: Collision) bool {
        return collision.entity || collision.wall != null;
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
