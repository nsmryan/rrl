const std = @import("std");

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

//pub fn pathBlockedFov(map: Map, start_pos: Pos, end_pos: Pos) ?Blocked {
//    return pathBlocked(map, start_pos, end_pos, BlockedType.fov);
//}
//
//pub fn pathBlockedFovLow(map: Map, start_pos: Pos, end_pos: Pos) ?Blocked {
//    return pathBlocked(map, start_pos, end_pos, BlockedType.fovLow);
//}
//
//pub fn pathBlockedMove(map: Map, start_pos: Pos, end_pos: Pos) ?Blocked {
//    return pathBlocked(map, start_pos, end_pos, BlockedType.move);
//}
//
//pub fn pathBlocked(map: Map, start_pos: Pos, end_pos: Pos, blocked_type: BlockedType) ?Blocked {
//    var line = line(start_pos, end_pos);
//    const positions = iter::once(start_pos).chain(line.into_iter());
//    for (pos, target_pos) in positions.tuple_windows() {
//        let blocked = self.move_blocked(pos, target_pos, blocked_type);
//        if blocked.is_some() {
//            return blocked;
//        }
//    }
//
//    return null;
//}

//
//    pub fn path_blocked_all(&self, start_pos: Pos, end_pos: Pos, blocked_type: BlockedType) -> Vec<Blocked> {
//        let mut blocked_vec = Vec::new();
//        let mut cur_pos = start_pos;
//        while let Some(blocked) = self.path_blocked(cur_pos, end_pos, blocked_type) {
//            blocked_vec.push(blocked);
//            cur_pos = blocked.end_pos;
//        }
//        return blocked_vec;
//    }
//
//
////    pub fn does_tile_block(self, block_type: BlockedType) -> bool {
//        match block_type {
//            BlockedType::Fov => {
//                return self.block_sight;
//            }
//
//            BlockedType::FovLow => {
//                return self.block_sight;
//            }
//
//            BlockedType::Move => {
//                return self.block_move;
//            }
//        }
//    }
//
//    pub fn does_left_block(&self) -> bool {
//        return self.left_wall != Wall::Empty && self.left_material != Material::Grass;
//    }
//
//    pub fn does_down_block(&self) -> bool {
//        return self.bottom_wall != Wall::Empty && self.bottom_material != Material::Grass;
//    }
//
pub const Rotation = enum {
    degrees0,
    degrees90,
    degrees180,
    degrees270,

    pub fn rotate(self: Rotation, position: Pos, width: i32, height: i32) Pos {
        var result = position;
        switch (self) {
            .degrees0 => {},

            .degrees90 => {
                // 90 degrees: swap x and y, mirror in x
                result = Pos.init(result.y, result.x);
                result = result.mirrorInX(width);
            },

            .degrees180 => {
                // 180 degrees: mirror in x, mirror in y
                result = result.mirrorInX(width);
                result = result.mirrorInY(height);
            },

            .degrees270 => {
                // 270: swap x and y, mirror in y
                result = Pos.init(result.y, result.x);
                result = result.mirrorInY(height);
            },
        }

        return result;
    }
};

test "test rotation" {
    const position = Pos.init(0, 0);
    const width: i32 = 10;
    const height: i32 = 20;

    try std.testing.expectEqual(position, Rotation.degrees0.rotate(position, width, height));
    try std.testing.expectEqual(Pos.init(width - 1, 0), Rotation.degrees90.rotate(position, width, height));
    try std.testing.expectEqual(Pos.init(width - 1, height - 1), Rotation.degrees180.rotate(position, width, height));
    try std.testing.expectEqual(Pos.init(0, height - 1), Rotation.degrees270.rotate(position, width, height));
}
//
//pub fn reorient_map(map: &Map, rotation: Rotation, mirror: bool) -> Map {
//    let (width, height) = map.size();
//
//    let (mut new_width, mut new_height) = (width, height);
//    if rotation == Rotation::Degrees90 or rotation == Rotation::Degrees270 {
//        new_width = height;
//        new_height = width;
//    }
//    let mut new_map = Map::from_dims(new_width as u32, new_height as u32);
//
//    let mut left_walls = Vec::new();
//    let mut bottom_walls = Vec::new();
//    for x in 0..width {
//        for y in 0..height {
//            let orig_pos = Pos::new(x, y);
//
//            let mut pos = Pos::new(x, y);
//            if mirror {
//                pos = pos.mirrorInX(width);
//            }
//            pos = rotation.rotate(pos, new_width, new_height);
//            new_map[pos] = map[orig_pos];
//
//            if map[orig_pos].left_wall != Wall::Empty {
//                left_walls.push((pos, map[orig_pos].left_wall, map[orig_pos].left_material));
//            }
//
//            if map[orig_pos].bottom_wall != Wall::Empty {
//                bottom_walls.push((pos, map[orig_pos].bottom_wall, map[orig_pos].bottom_material));
//            }
//        }
//    }
//
//    for x in 0..new_width {
//        for y in 0..new_height {
//            let pos = Pos::new(x, y);
//            new_map[pos].left_wall = Wall::Empty;
//            new_map[pos].bottom_wall = Wall::Empty;
//        }
//    }
//
//    for (wall_pos, wall_type, material) in left_walls {
//        match rotation {
//            Rotation::Degrees0 => {
//                new_map[wall_pos].left_wall = wall_type;
//                new_map[wall_pos].left_material = material;
//            }
//
//            Rotation::Degrees90 => {
//                let new_wall_pos = move_y(wall_pos, -1);
//                if new_map.is_within_bounds(new_wall_pos) {
//                    new_map[new_wall_pos].bottom_wall = wall_type;
//                    new_map[wall_pos].bottom_material = material;
//                }
//            }
//
//            Rotation::Degrees180 => {
//                let new_wall_pos = moveX(wall_pos, 1);
//                if new_map.is_within_bounds(new_wall_pos) {
//                    new_map[new_wall_pos].left_wall = wall_type;
//                    new_map[wall_pos].left_material = material;
//                }
//            }
//
//            Rotation::Degrees270 => {
//                new_map[wall_pos].bottom_wall = wall_type;
//                new_map[wall_pos].bottom_material = material;
//            }
//        }
//    }
//
//    for (wall_pos, wall_type, material) in bottom_walls {
//        match rotation {
//            Rotation::Degrees0 => {
//                new_map[wall_pos].bottom_wall = wall_type;
//                new_map[wall_pos].bottom_material = material;
//            }
//
//            Rotation::Degrees90 => {
//                new_map[wall_pos].left_wall = wall_type;
//                new_map[wall_pos].left_material = material;
//            }
//
//            Rotation::Degrees180 => {
//                let new_wall_pos = move_y(wall_pos, -1);
//                if new_map.is_within_bounds(new_wall_pos) {
//                    new_map[new_wall_pos].bottom_wall = wall_type;
//                    new_map[wall_pos].bottom_material = material;
//                }
//            }
//
//            Rotation::Degrees270 => {
//                let new_wall_pos = moveX(wall_pos, 1);
//                if new_map.is_within_bounds(new_wall_pos) {
//                    new_map[new_wall_pos].left_wall = wall_type;
//                    new_map[wall_pos].left_material = material;
//                }
//            }
//        }
//    }
//
//    return new_map;
//}

