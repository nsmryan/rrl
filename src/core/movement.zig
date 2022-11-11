const board = @import("board");
const Height = board.tile.Tile.Height;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

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
