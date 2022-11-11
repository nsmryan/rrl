const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");

const tile = @import("tile.zig");
const Tile = tile.Tile;
const Material = Tile.Material;
const Height = Tile.Height;
const Wall = Tile.Wall;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

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

pub fn blockedDir(map: *const Map, position: Pos, dir: Direction, blocked_type: BlockedType) Height {
    return switch (dir) {
        .left => blockedLeft(map, position, blocked_type),
        .right => blockedRight(map, position, blocked_type),
        .up => blockedUp(map, position, blocked_type),
        .down => blockedDown(map, position, blocked_type),
        .upLeft => blockedLeft(map, position, blocked_type).meet(blockedUp(map, position, blocked_type)),
        .upRight => blockedRight(map, position, blocked_type).meet(blockedUp(map, position, blocked_type)),
        .downLeft => blockedDown(map, position, blocked_type).meet(blockedLeft(map, position, blocked_type)),
        .downRight => blockedDown(map, position, blocked_type).meet(blockedRight(map, position, blocked_type)),
    };
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

    // If moving into a blocked tile, we are blocked.
    blocked.height = blocked_type.tileBlocks(map.get(end_pos));
    if (blocked.height != .empty) {
        blocked.blocked_tile = true;
    }

    if (dir.horiz()) {
        blocked.height = blockedDir(map, start_pos, dir, blocked_type);
    } else {
        // Forward
        blocked.height = blockedDir(map, start_pos, dir, blocked_type);

        // Back
        blocked.height = blocked.height.join(blockedDir(map, end_pos, dir.reverse(), blocked_type));

        // One Side
        const clockwise_dir = dir.clockwise();
        const counterclockwise_dir = dir.counterclockwise();

        const height0 = blockedDir(map, start_pos, clockwise_dir, blocked_type);
        const height1 = blockedDir(map, counterclockwise_dir.offsetPos(start_pos, 1), clockwise_dir, blocked_type);
        blocked.height = blocked.height.join(height0.meet(height1));

        // Other Size
        const height2 = blockedDir(map, start_pos, counterclockwise_dir, blocked_type);
        const height3 = blockedDir(map, clockwise_dir.offsetPos(start_pos, 1), counterclockwise_dir, blocked_type);
        blocked.height = blocked.height.join(height2.meet(height3));
    }

    if (blocked.height == .empty) {
        return null;
    } else {
        return blocked;
    }
}

test "move blocked" {
    var allocator = std.testing.allocator;

    const start = Pos.init(1, 1);

    var map = try Map.fromDims(3, 3, allocator);
    defer map.deinit();

    const directions: [4]Direction = .{ .left, .right, .up, .down };
    for (directions) |dir| {
        const diag_dir = dir.clockwise();
        const perp_dir = diag_dir.clockwise();

        try std.testing.expect(null == moveBlocked(&map, start, dir, BlockedType.move));

        // A tile with a wall is blocked.
        map.getPtr(dir.offsetPos(start, 1)).center.height = .short;
        var blocked = Blocked.init(start, dir.offsetPos(start, 1), dir, true, .short);
        try std.testing.expectEqual(blocked, moveBlocked(&map, start, dir, BlockedType.move).?);

        // A tile with an intertile wall is blocked to direct movement.
        map.clear();
        map.placeIntertileDir(start, dir, Wall.init(Height.short, Material.stone));
        blocked = Blocked.init(start, dir.offsetPos(start, 1), dir, false, .short);
        try std.testing.expectEqual(blocked, moveBlocked(&map, start, dir, BlockedType.move).?);

        // A tile with a short wall does not block FoV.
        map.clear();
        map.placeIntertileDir(start, dir, Wall.init(Height.short, Material.stone));
        try std.testing.expect(null == moveBlocked(&map, start, dir, BlockedType.fov));

        // A tile with a short grass wall does not block movement.
        map.clear();
        map.placeIntertileDir(start, dir, Wall.init(Height.short, Material.grass));
        try std.testing.expect(null == moveBlocked(&map, start, dir, BlockedType.move));

        // A tile with a short stone wall does not block diagonal movement.
        map.clear();
        map.placeIntertileDir(start, dir, Wall.init(Height.short, Material.stone));
        try std.testing.expect(null == moveBlocked(&map, start, diag_dir, BlockedType.move));

        // A tile with a short stone wall in the other direction also does not block diagonal movement.
        map.placeIntertileDir(start, diag_dir, Wall.init(Height.short, Material.stone));
        map.placeIntertileDir(start, dir, Wall.empty());
        try std.testing.expect(null == moveBlocked(&map, start, diag_dir, BlockedType.move));

        // Short walls in both corners do block diagonal movement.
        map.placeIntertileDir(start, dir, Wall.init(Height.short, Material.stone));
        blocked = Blocked.init(start, diag_dir.offsetPos(start, 1), diag_dir, false, .short);
        try std.testing.expectEqual(blocked, moveBlocked(&map, start, diag_dir, BlockedType.move).?);

        map.clear();
        map.placeIntertileDir(start, dir, Wall.init(Height.short, Material.stone));
        try std.testing.expect(null == moveBlocked(&map, start, diag_dir, BlockedType.move));

        map.placeIntertileDir(diag_dir.offsetPos(start, 1), perp_dir.reverse(), Wall.init(Height.short, Material.stone));
        map.placeIntertileDir(start, dir, Wall.init(Height.short, Material.stone));
        try std.testing.expect(null == moveBlocked(&map, start, diag_dir, BlockedType.move));

        map.placeIntertileDir(perp_dir.offsetPos(start, 1), dir, Wall.init(Height.short, Material.stone));
        map.placeIntertileDir(diag_dir.offsetPos(start, 1), perp_dir.reverse(), Wall.init(Height.short, Material.stone));
        blocked = Blocked.init(start, diag_dir.offsetPos(start, 1), diag_dir, false, .short);
        try std.testing.expectEqual(blocked, moveBlocked(&map, start, diag_dir, BlockedType.move).?);
    }
}

pub fn reachableNeighbors(map: *const Map, start: Pos, blocked_type: BlockedType, neighbors: *ArrayList(Pos)) !void {
    neighbors.clearRetainingCapacity();

    for (Direction.directions()) |dir| {
        if (moveBlocked(map, start, dir, blocked_type) == null) {
            try neighbors.append(dir.offsetPos(start, 1));
        }
    }
}

test "reachable neighbors" {
    var allocator = std.testing.allocator;
    var map = try Map.fromDims(3, 3, allocator);
    defer map.deinit();

    const start = Pos.init(0, 0);
    map.getPtr(Pos.init(1, 0)).center = tile.Tile.Wall.tall();
    map.getPtr(Pos.init(1, 1)).center = tile.Tile.Wall.tall();

    var neighbors = ArrayList(Pos).init(allocator);
    defer neighbors.deinit();

    try reachableNeighbors(&map, start, BlockedType.move, &neighbors);

    try std.testing.expectEqual(@as(usize, 1), neighbors.items.len);
    try std.testing.expectEqual(Pos.init(0, 1), neighbors.items[0]);

    // NOTE Using 'neighbors.items[0]' directly causes this test to fail. This seems like a bug in zig.
    const new_pos = neighbors.items[0];
    try reachableNeighbors(&map, new_pos, BlockedType.move, &neighbors);
    try std.testing.expectEqual(@as(usize, 3), neighbors.items.len);
    try std.testing.expectEqual(Pos.init(0, 0), neighbors.items[0]);
    try std.testing.expectEqual(Pos.init(1, 2), neighbors.items[1]);
    try std.testing.expectEqual(Pos.init(0, 2), neighbors.items[2]);
}
