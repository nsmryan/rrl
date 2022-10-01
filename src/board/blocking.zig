const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const pos = utils.pos;
const Pos = pos.Pos;
const Direction = utils.direction.Direction;

const tile = @import("tile.zig");
const Tile = tile.Tile;
const Material = Tile.Material;
const Wall = Tile.Wall;

const Map = @import("map.zig").Map;

pub const FovResult = enum {
    outside,
    edge,
    inside,

    pub fn combine(self: FovResult, other: FovResult) FovResult {
        if (self == .inside or other == .inside) {
            return .inside;
        } else if (self == .edge or other == .edge) {
            return .edge;
        } else {
            return .outside;
        }
    }
};

pub const Blocked = struct {
    start_pos: Pos,
    end_pos: Pos,
    direction: Direction,
    blocked_tile: bool,
    wall: Wall,

    pub fn init(start_pos: Pos, end_pos: Pos, dir: Direction, blocked_tile: bool, wall: Wall) Blocked {
        return Blocked{ .start_pos = start_pos, .end_pos = end_pos, .direction = dir, .blocked_tile = blocked_tile, .wall = wall };
    }
};

pub const BlockedType = enum {
    fov,
    fovLow,
    move,

    pub fn wallBlocks(self: BlockedType, wall: Wall) bool {
        return switch (self) {
            .fov => wall.height == .tall,
            .fovLow => wall.height != .empty,
            .move => wall.height != .empty and wall.material != .grass,
        };
    }

    pub fn tileBlocks(self: BlockedType, checkTile: Tile) bool {
        return tile.impassable || self.wallBlocks(checkTile.wall);
    }

    pub fn tileBlocksLeft(self: BlockedType, checkTile: Tile) bool {
        return self.wallBlocks(checkTile.left);
    }

    pub fn tileBlocksDown(self: BlockedType, checkTile: Tile) bool {
        return self.wallBlocks(checkTile.down);
    }
};

test "test blocked type" {
    try std.testing.expect(!BlockedType.fov.wallBlocks(Wall.init(.short, .stone)));
    try std.testing.expect(!BlockedType.fov.wallBlocks(Wall.init(.short, .grass)));
    try std.testing.expect(BlockedType.fov.wallBlocks(Wall.init(.tall, .stone)));
    try std.testing.expect(!BlockedType.fov.wallBlocks(Wall.init(.empty, .stone)));
    try std.testing.expect(!BlockedType.fov.wallBlocks(Wall.init(.empty, .grass)));

    try std.testing.expect(BlockedType.fovLow.wallBlocks(Wall.init(.short, .stone)));
    try std.testing.expect(BlockedType.fovLow.wallBlocks(Wall.init(.tall, .stone)));
    try std.testing.expect(BlockedType.fovLow.wallBlocks(Wall.init(.short, .grass)));
    try std.testing.expect(BlockedType.fovLow.wallBlocks(Wall.init(.tall, .grass)));
    try std.testing.expect(!BlockedType.fovLow.wallBlocks(Wall.init(.empty, .stone)));
    try std.testing.expect(!BlockedType.fovLow.wallBlocks(Wall.init(.empty, .grass)));

    try std.testing.expect(!BlockedType.move.wallBlocks(Wall.init(.empty, .stone)));
    try std.testing.expect(BlockedType.move.wallBlocks(Wall.init(.short, .stone)));
    try std.testing.expect(!BlockedType.move.wallBlocks(Wall.init(.tall, .grass)));
    try std.testing.expect(!BlockedType.move.wallBlocks(Wall.init(.short, .grass)));
    try std.testing.expect(BlockedType.move.wallBlocks(Wall.init(.tall, .stone)));
}

pub fn blockedLeft(map: *const Map, position: Pos, blocked_type: BlockedType) bool {
    const offset = position.moveX(-1);
    if (!map.isWithinBounds(offset)) {
        return true;
    }
    const blocking_wall = blocked_type.tileBlocksLeft(map.get(position));
    const blocking_tile = blocked_type.tileBlocks(map.get(offset));
    return blocking_wall or blocking_tile;
}

pub fn blockedRight(map: *const Map, position: Pos, blocked_type: BlockedType) bool {
    const offset = position.moveX(1);
    if (!map.isWithinBounds(offset)) {
        return true;
    }

    const blocking_wall = blocked_type.tileBlocksLeft(map.get(offset));
    const blocking_tile = blocked_type.tileBlocks(map.get(offset));
    return blocking_wall or blocking_tile;
}

pub fn blockedDown(map: *const Map, position: Pos, blocked_type: BlockedType) bool {
    const offset = position.moveY(1);
    if (!map.is_within_bounds(offset)) {
        return true;
    }

    const blocking_wall = blocked_type.tileBlocksDown(map.get(position));
    const blocking_tile = blocked_type.tileBlocks(map.get(offset));
    return blocking_wall or blocking_tile;
}

pub fn blockedUp(map: *const Map, position: Pos, blocked_type: BlockedType) bool {
    const offset = position.moveY(-1);
    if (!map.is_within_bounds(offset)) {
        return true;
    }

    const blocking_wall = blocked_type.tileBlocksDown(map.get(offset));
    const blocking_tile = blocked_type.tileBlocks(map.get(offset));
    return blocking_wall or blocking_tile;
}

pub fn moveBlocked(map: *const Map, start_pos: Pos, dir: Direction, blocked_type: BlockedType) ?Blocked {
    const end_pos = dir.offsetPos(start_pos, 1);
    var blocked = Blocked.init(start_pos, end_pos, dir, false, Wall.empty);

    // if the target position is out of bounds, we are blocked
    if (!map.is_within_bounds(end_pos)) {
        blocked.blocked_tile = true;
        return blocked;
    }

    var found_blocker = false;

    // if moving into a blocked tile, we are blocked
    if (blocked_type.tileBlocks(map.get(end_pos))) {
        blocked.blocked_tile = true;
        found_blocker = true;
    }

    switch (dir) {
        Direction.left => {
            if (blockedLeft(map, start_pos, blocked_type)) {
                blocked.wall = map.get(start_pos).left.wall;
                found_blocker = true;
            }
        },

        Direction.right => {
            if (blockedRight(map, start_pos, blocked_type)) {
                blocked.wall = map.get(end_pos).left.wall;
                found_blocker = true;
            }
        },

        Direction.down => {
            if (blockedDown(map, start_pos, blocked_type)) {
                blocked.wall = map.get(start_pos).down.wall;
                found_blocker = true;
            }
        },

        Direction.up => {
            if (blockedUp(map, start_pos, blocked_type)) {
                blocked.wall = map.get(end_pos).down.wall;
                found_blocker = true;
            }
        },

        Direction.downRight => {
            // Check _|
            if (blockedRight(map, start_pos, blocked_type) and blockedDown(map, start_pos, blocked_type)) {
                blocked.wall = map.get(start_pos).down.wall;
                found_blocker = true;
            }

            // Check   _
            //        |
            if (blockedLeft(map, end_pos, blocked_type) and blockedUp(map, end_pos, blocked_type)) {
                blocked.wall = map.get(end_pos).left.wall;
                found_blocker = true;
            }

            // Check |
            //       |
            if (blockedRight(map, start_pos, blocked_type) and blockedLeft(map, end_pos, blocked_type)) {
                blocked.wall = map.get(end_pos).left.wall;
                found_blocker = true;
            }

            // Check __
            if (blockedDown(map, start_pos, blocked_type) and blockedUp(map, end_pos, blocked_type)) {
                blocked.wall = map.get(start_pos).down.wall;
                found_blocker = true;
            }
        },

        Direction.upRight => {
            // Check for |_
            if (blockedDown(map, end_pos, blocked_type) and blockedLeft(map, end_pos, blocked_type)) {
                blocked.wall = map.get(end_pos).down.wall;
                found_blocker = true;
            }

            // Check for _
            //            |
            if (blockedRight(map, start_pos, blocked_type) and blockedUp(map, start_pos, blocked_type)) {
                blocked.wall = map.get(start_pos.moveY(-1)).down.wall;
                found_blocker = true;
            }

            // Check for |
            //           |
            if (blockedRight(map, start_pos, blocked_type) and blockedLeft(map, end_pos, blocked_type)) {
                blocked.wall = map.get(end_pos).left.wall;
                found_blocker = true;
            }

            // Check for __
            if (blockedUp(map, start_pos, blocked_type) and blockedDown(map, end_pos, blocked_type)) {
                blocked.wall = map.get(end_pos).down.wall;
                found_blocker = true;
            }
        },

        Direction.downLeft => {
            // Check for |_
            if (blockedLeft(map, start_pos, blocked_type) and blockedDown(map, start_pos, blocked_type)) {
                blocked.wall = map.get(start_pos).left.wall;
                found_blocker = true;
            }

            // Check for _
            //            |
            if (blockedRight(map, end_pos, blocked_type) and blockedUp(map, end_pos, blocked_type)) {
                blocked.wall = map.get(start_pos.moveY(1)).left.wall;
                found_blocker = true;
            }

            // Check for |
            //           |
            if (blockedLeft(map, start_pos, blocked_type) and map.blockedRight(map, end_pos, blocked_type)) {
                blocked.wall = map.get(start_pos).left.wall;
                found_blocker = true;
            }

            // Check for __
            if (blockedDown(map, start_pos, blocked_type) and blockedUp(map, end_pos, blocked_type)) {
                blocked.wall = map.get(start_pos).down.wall;
                found_blocker = true;
            }
        },

        Direction.upLeft => {
            // Check for |
            //          _
            if (blockedRight(map, end_pos, blocked_type) and map.blockedRight(map, end_pos, blocked_type)) {
                blocked.wall = map.get(end_pos).down.wall;
                found_blocker = true;
            }

            // Check for _
            //          |
            if (blockedLeft(map, start_pos, blocked_type) and blockedUp(map, start_pos, blocked_type)) {
                blocked.wall = map.get(start_pos).left.wall;
                found_blocker = true;
            }

            // Check for |
            //           |
            if (blockedLeft(map, start_pos, blocked_type) and blockedRight(map, end_pos, blocked_type)) {
                blocked.wall = map.get(start_pos).left.wall;
                found_blocker = true;
            }

            // Check for __
            if (blockedUp(map, start_pos, blocked_type) and map.blockedDown(map, end_pos, blocked_type)) {
                blocked.wall = map.get(end_pos).down.wall;
                found_blocker = true;
            }
        },
    }

    if (found_blocker) {
        return blocked;
    } else {
        return null;
    }
}
