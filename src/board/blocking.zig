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
const Height = Tile.Height;
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
    height: Height,

    pub fn init(start_pos: Pos, end_pos: Pos, dir: Direction, blocked_tile: bool, height: Height) Blocked {
        return Blocked{ .start_pos = start_pos, .end_pos = end_pos, .direction = dir, .blocked_tile = blocked_tile, .height = height };
    }
};

pub const BlockedType = enum {
    fov,
    fovLow,
    move,

    pub fn wallBlocks(self: BlockedType, wall: Wall) Height {
        return switch (self) {
            .fov => {
                if (wall.height == .tall) {
                    return .tall;
                } else {
                    return .empty;
                }
            },

            .fovLow => {
                return wall.height;
            },

            .move => {
                if (wall.height != .empty and wall.material != .grass) {
                    return wall.height;
                } else {
                    return .empty;
                }
            },
        };
    }

    pub fn tileBlocks(self: BlockedType, checkTile: Tile) Height {
        if (checkTile.impassable) {
            return .tall;
        } else {
            return self.wallBlocks(checkTile.center);
        }
    }

    pub fn tileBlocksLeft(self: BlockedType, checkTile: Tile) Height {
        return self.wallBlocks(checkTile.left);
    }

    pub fn tileBlocksDown(self: BlockedType, checkTile: Tile) Height {
        return self.wallBlocks(checkTile.down);
    }
};

test "test blocked type" {
    try std.testing.expectEqual(Height.empty, BlockedType.fov.wallBlocks(Wall.init(.short, .stone)));
    try std.testing.expectEqual(Height.empty, BlockedType.fov.wallBlocks(Wall.init(.short, .grass)));
    try std.testing.expectEqual(Height.tall, BlockedType.fov.wallBlocks(Wall.init(.tall, .stone)));
    try std.testing.expectEqual(Height.empty, BlockedType.fov.wallBlocks(Wall.init(.empty, .stone)));
    try std.testing.expectEqual(Height.empty, BlockedType.fov.wallBlocks(Wall.init(.empty, .grass)));

    try std.testing.expectEqual(Height.short, BlockedType.fovLow.wallBlocks(Wall.init(.short, .stone)));
    try std.testing.expectEqual(Height.tall, BlockedType.fovLow.wallBlocks(Wall.init(.tall, .stone)));
    try std.testing.expectEqual(Height.short, BlockedType.fovLow.wallBlocks(Wall.init(.short, .grass)));
    try std.testing.expectEqual(Height.tall, BlockedType.fovLow.wallBlocks(Wall.init(.tall, .grass)));
    try std.testing.expectEqual(Height.empty, BlockedType.fovLow.wallBlocks(Wall.init(.empty, .stone)));
    try std.testing.expectEqual(Height.empty, BlockedType.fovLow.wallBlocks(Wall.init(.empty, .grass)));

    try std.testing.expectEqual(Height.empty, BlockedType.move.wallBlocks(Wall.init(.empty, .stone)));
    try std.testing.expectEqual(Height.short, BlockedType.move.wallBlocks(Wall.init(.short, .stone)));
    try std.testing.expectEqual(Height.empty, BlockedType.move.wallBlocks(Wall.init(.tall, .grass)));
    try std.testing.expectEqual(Height.empty, BlockedType.move.wallBlocks(Wall.init(.short, .grass)));
    try std.testing.expectEqual(Height.tall, BlockedType.move.wallBlocks(Wall.init(.tall, .stone)));
}

pub fn blockedLeft(map: *const Map, position: Pos, blocked_type: BlockedType) Height {
    const offset = position.moveX(-1);
    if (!map.isWithinBounds(offset)) {
        return .tall;
    }
    const blocking_wall = blocked_type.tileBlocksLeft(map.get(position));
    const blocking_tile = blocked_type.tileBlocks(map.get(offset));
    return blocking_wall.join(blocking_tile);
}

pub fn blockedRight(map: *const Map, position: Pos, blocked_type: BlockedType) Height {
    const offset = position.moveX(1);
    if (!map.isWithinBounds(offset)) {
        return .tall;
    }

    const blocking_wall = blocked_type.tileBlocksLeft(map.get(offset));
    const blocking_tile = blocked_type.tileBlocks(map.get(offset));
    return blocking_wall.join(blocking_tile);
}

pub fn blockedDown(map: *const Map, position: Pos, blocked_type: BlockedType) Height {
    const offset = position.moveY(1);
    if (!map.isWithinBounds(offset)) {
        return .tall;
    }

    const blocking_wall = blocked_type.tileBlocksDown(map.get(position));
    const blocking_tile = blocked_type.tileBlocks(map.get(offset));
    return blocking_wall.join(blocking_tile);
}

pub fn blockedUp(map: *const Map, position: Pos, blocked_type: BlockedType) Height {
    const offset = position.moveY(-1);
    if (!map.isWithinBounds(offset)) {
        return .tall;
    }

    const blocking_wall = blocked_type.tileBlocksDown(map.get(offset));
    const blocking_tile = blocked_type.tileBlocks(map.get(offset));
    return blocking_wall.join(blocking_tile);
}

pub fn moveBlocked(map: *const Map, start_pos: Pos, dir: Direction, blocked_type: BlockedType) ?Blocked {
    const end_pos = dir.offsetPos(start_pos, 1);
    var blocked = Blocked.init(start_pos, end_pos, dir, false, .empty);

    // If the target position is out of bounds, we are blocked.
    if (!map.isWithinBounds(end_pos)) {
        blocked.blocked_tile = true;
        blocked.height = .tall;
        return blocked;
    }

    var found_blocker = false;

    // If moving into a blocked tile, we are blocked.
    blocked.height = blocked_type.tileBlocks(map.get(end_pos));
    if (blocked.height != .empty) {
        blocked.blocked_tile = true;
        found_blocker = true;
    }

    switch (dir) {
        Direction.left => {
            blocked.height = blockedLeft(map, start_pos, blocked_type);
            found_blocker = blocked.height != .empty;
        },

        Direction.right => {
            blocked.height = blockedRight(map, start_pos, blocked_type);
            found_blocker = blocked.height != .empty;
        },

        Direction.down => {
            blocked.height = blockedDown(map, start_pos, blocked_type);
            found_blocker = blocked.height != .empty;
        },

        Direction.up => {
            blocked.height = blockedUp(map, start_pos, blocked_type);
            found_blocker = blocked.height != .empty;
        },

        Direction.downRight => {
            // Check _|
            blocked.height = blockedRight(map, start_pos, blocked_type).meet(blockedDown(map, start_pos, blocked_type));

            // Check   _
            //        |
            blocked.height = blockedLeft(map, end_pos, blocked_type).meet(blockedUp(map, end_pos, blocked_type));

            // Check |
            //       |
            blocked.height = blockedRight(map, start_pos, blocked_type).meet(blockedLeft(map, end_pos, blocked_type));

            // Check __
            blocked.height = blockedDown(map, start_pos, blocked_type).meet(blockedUp(map, end_pos, blocked_type));

            found_blocker = blocked.height != .empty;
        },

        Direction.upRight => {
            // Check for |_
            blocked.height = blockedDown(map, end_pos, blocked_type).meet(blockedLeft(map, end_pos, blocked_type));

            // Check for _
            //            |
            blocked.height = blockedRight(map, start_pos, blocked_type).meet(blockedUp(map, start_pos, blocked_type));

            // Check for |
            //           |
            blocked.height = blockedRight(map, start_pos, blocked_type).meet(blockedLeft(map, end_pos, blocked_type));

            // Check for __
            blocked.height = blockedUp(map, start_pos, blocked_type).meet(blockedDown(map, end_pos, blocked_type));

            found_blocker = blocked.height != .empty;
        },

        Direction.downLeft => {
            // Check for |_
            blocked.height = blockedLeft(map, start_pos, blocked_type).meet(blockedDown(map, start_pos, blocked_type));

            // Check for _
            //            |
            blocked.height = blockedRight(map, end_pos, blocked_type).meet(blockedUp(map, end_pos, blocked_type));

            // Check for |
            //           |
            blocked.height = blockedLeft(map, start_pos, blocked_type).meet(blockedRight(map, end_pos, blocked_type));

            // Check for __
            blocked.height = blockedDown(map, start_pos, blocked_type).meet(blockedUp(map, end_pos, blocked_type));

            found_blocker = blocked.height != .empty;
        },

        Direction.upLeft => {
            // Check for |
            //          _
            blocked.height = blockedRight(map, end_pos, blocked_type).meet(blockedDown(map, end_pos, blocked_type));

            // Check for _
            //          |
            blocked.height = blocked.height.join(blockedLeft(map, start_pos, blocked_type).meet(blockedUp(map, start_pos, blocked_type)));

            // Check for |
            //           |
            blocked.height = blocked.height.join(blockedLeft(map, start_pos, blocked_type).meet(blockedRight(map, end_pos, blocked_type)));

            // Check for __
            blocked.height = blocked.height.join(blockedUp(map, start_pos, blocked_type).meet(blockedDown(map, end_pos, blocked_type)));

            found_blocker = blocked.height != .empty;
        },
    }

    if (found_blocker) {
        return blocked;
    } else {
        return null;
    }
}

test "move blocked" {
    var allocator = std.testing.allocator;

    const start = Pos.init(2, 2);

    {
        var map = try Map.fromDims(5, 5, allocator);
        defer map.deinit(allocator);
        try std.testing.expect(null == moveBlocked(&map, start, Direction.left, BlockedType.move));
    }

    {
        var map = try Map.fromDims(5, 5, allocator);
        defer map.deinit(allocator);

        map.getPtr(start.moveX(-1)).center.height = .short;
        const blocked = Blocked.init(start, start.moveX(-1), .left, true, .short);
        try std.testing.expectEqual(blocked, moveBlocked(&map, start, Direction.left, BlockedType.move).?);
    }

    {
        var map = try Map.fromDims(5, 5, allocator);
        defer map.deinit(allocator);

        map.getPtr(start).left.height = .short;
        const blocked = Blocked.init(start, start.moveX(-1), .left, false, .short);
        try std.testing.expectEqual(blocked, moveBlocked(&map, start, Direction.left, BlockedType.move).?);
    }

    {
        var map = try Map.fromDims(5, 5, allocator);
        defer map.deinit(allocator);

        map.getPtr(start).left.height = .short;
        try std.testing.expect(null == moveBlocked(&map, start, Direction.left, BlockedType.fov));
    }

    {
        var map = try Map.fromDims(5, 5, allocator);
        defer map.deinit(allocator);

        map.getPtr(start).left.height = .short;
        map.getPtr(start).left.material = .grass;
        try std.testing.expect(null == moveBlocked(&map, start, Direction.left, BlockedType.move));
    }

    {
        var map = try Map.fromDims(5, 5, allocator);
        defer map.deinit(allocator);

        map.getPtr(start).left.height = .short;
        try std.testing.expect(null == moveBlocked(&map, start, Direction.upLeft, BlockedType.move));

        map.getPtr(start.moveY(-1)).down.height = .short;
        map.getPtr(start).left.height = .empty;
        try std.testing.expect(null == moveBlocked(&map, start, Direction.upLeft, BlockedType.move));

        map.getPtr(start).left.height = .short;
        const blocked = Blocked.init(start, start.moveX(-1).moveY(-1), .upLeft, false, .short);
        try std.testing.expectEqual(blocked, moveBlocked(&map, start, Direction.upLeft, BlockedType.move).?);
    }

    {
        var map = try Map.fromDims(5, 5, allocator);
        defer map.deinit(allocator);

        map.getPtr(start.moveY(-1)).left.height = .short;
        try std.testing.expect(null == moveBlocked(&map, start, Direction.upLeft, BlockedType.move));

        map.getPtr(start.moveY(-1).moveX(-1)).down.height = .short;
        map.getPtr(start.moveY(-1)).left.height = .empty;
        try std.testing.expect(null == moveBlocked(&map, start, Direction.upLeft, BlockedType.move));

        map.getPtr(start.moveY(-1)).left.height = .short;
        map.getPtr(start.moveY(-1).moveX(-1)).down.height = .short;
        const blocked = Blocked.init(start, start.moveX(-1).moveY(-1), .upLeft, false, .short);
        try std.testing.expectEqual(blocked, moveBlocked(&map, start, Direction.upLeft, BlockedType.move).?);
    }
}
