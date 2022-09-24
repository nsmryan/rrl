const direction = @import("direction.zig");
const Direction = direction.Direction;

const pos = @import("pos.zig");
const Pos = pos.Pos;

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
    wall_type: Wall,

    pub fn init(start_pos: Pos, end_pos: Pos, direction: Direction, blocked_tile: bool, wall_type: Wall) Blocked {
        return Blocked{ .start_pos = start_pos, .end_pos = end_pos, .direction = direction, .blocked_tile = blocked_tile, .wall_type = wall_type };
    }
};

pub const BlockedType = enum {
    fov,
    fovLow,
    move,
};

//    pub fn blocking(&self, wall: Wall, material: Surface) -> bool {
//        let walk_into = *self == BlockedType::Move && (wall == Wall::Empty || material == Surface::Grass);
//        let see_over = (*self == BlockedType::Fov && wall != Wall::TallWall) || (*self == BlockedType::FovLow && wall == Wall::Empty);
//        return !walk_into && !see_over;
//    }
//#[test]
//fn test_blocked_type() {
//    assert_eq!(false, BlockedType::Fov.blocking(Wall::ShortWall, Surface::Floor));
//    assert_eq!(false, BlockedType::Fov.blocking(Wall::ShortWall, Surface::Grass));
//    assert_eq!(true, BlockedType::Fov.blocking(Wall::TallWall, Surface::Floor));
//    assert_eq!(false, BlockedType::Fov.blocking(Wall::Empty, Surface::Floor));
//    assert_eq!(false, BlockedType::Fov.blocking(Wall::Empty, Surface::Grass));
//
//    assert_eq!(true, BlockedType::FovLow.blocking(Wall::ShortWall, Surface::Floor));
//    assert_eq!(true, BlockedType::FovLow.blocking(Wall::TallWall, Surface::Floor));
//    assert_eq!(true, BlockedType::FovLow.blocking(Wall::ShortWall, Surface::Grass));
//    assert_eq!(true, BlockedType::FovLow.blocking(Wall::TallWall, Surface::Grass));
//    assert_eq!(false, BlockedType::FovLow.blocking(Wall::Empty, Surface::Floor));
//    assert_eq!(false, BlockedType::FovLow.blocking(Wall::Empty, Surface::Grass));
//
//    assert_eq!(false, BlockedType::Move.blocking(Wall::Empty, Surface::Floor));
//    assert_eq!(true, BlockedType::Move.blocking(Wall::ShortWall, Surface::Floor));
//    assert_eq!(false, BlockedType::Move.blocking(Wall::TallWall, Surface::Grass));
//    assert_eq!(false, BlockedType::Move.blocking(Wall::ShortWall, Surface::Grass));
//    assert_eq!(true, BlockedType::Move.blocking(Wall::TallWall, Surface::Floor));
//}
//
//    pub fn blocked_left(&self, pos: Pos, blocked_type: BlockedType) -> bool {
//        let offset = Pos::new(pos.x - 1, pos.y);
//        if !self.is_within_bounds(pos) || !self.is_within_bounds(offset) {
//            return true;
//        }
//
//        let blocking_wall = blocked_type.blocking(self[pos].left_wall, self[pos].left_material);
//        let blocking_tile = self[offset].does_tile_block(blocked_type);
//        return blocking_wall || blocking_tile;
//    }
//
//    pub fn blocked_right(&self, pos: Pos, blocked_type: BlockedType) -> bool {
//        let offset = Pos::new(pos.x + 1, pos.y);
//        if !self.is_within_bounds(pos) || !self.is_within_bounds(offset) {
//            return true;
//        }
//
//        let blocking_wall = blocked_type.blocking(self[offset].left_wall, self[offset].left_material);
//        let blocking_tile = self[offset].does_tile_block(blocked_type);
//        return blocking_wall || blocking_tile;
//    }
//
//    pub fn blocked_down(&self, pos: Pos, blocked_type: BlockedType) -> bool {
//        let offset = Pos::new(pos.x, pos.y + 1);
//        if !self.is_within_bounds(pos) || !self.is_within_bounds(offset) {
//            return true;
//        }
//
//        let blocking_wall = blocked_type.blocking(self[pos].bottom_wall, self[pos].bottom_material);
//        let blocking_tile = self[offset].does_tile_block(blocked_type);
//        return blocking_wall || blocking_tile;
//    }
//
//    pub fn blocked_up(&self, pos: Pos, blocked_type: BlockedType) -> bool {
//        let offset = Pos::new(pos.x, pos.y - 1);
//        if !self.is_within_bounds(pos) || !self.is_within_bounds(offset) {
//            return true;
//        }
//
//        let blocking_wall = blocked_type.blocking(self[offset].bottom_wall, self[offset].bottom_material);
//        let blocking_tile = self[offset].does_tile_block(blocked_type);
//        return blocking_wall || blocking_tile;
//    }
//
//    pub fn path_blocked_fov(&self, start_pos: Pos, end_pos: Pos) -> Option<Blocked> {
//        return self.path_blocked(start_pos, end_pos, BlockedType::Fov);
//    }
//
//    pub fn path_blocked_fov_low(&self, start_pos: Pos, end_pos: Pos) -> Option<Blocked> {
//        return self.path_blocked(start_pos, end_pos, BlockedType::FovLow);
//    }
//
//    pub fn path_blocked_move(&self, start_pos: Pos, end_pos: Pos) -> Option<Blocked> {
//        return self.path_blocked(start_pos, end_pos, BlockedType::Move);
//    }
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
//    pub fn move_blocked(&self, start_pos: Pos, end_pos: Pos, blocked_type: BlockedType) -> Option<Blocked> {
//        let dxy = sub_pos(end_pos, start_pos);
//        if dxy.x == 0 && dxy.y == 0 {
//            return None;
//        }
//
//        let dir = Direction::from_dxy(dxy.x, dxy.y)
//                            .expect(&format!("Check for blocking wall with no movement {:?}?", dxy));
//
//
//        let mut blocked = Blocked::new(start_pos, end_pos, dir, false, Wall::Empty);
//
//        // if the target position is out of bounds, we are blocked
//        if !self.is_within_bounds(end_pos) {
//            blocked.blocked_tile = true;
//
//            // continuing to check after finding an out-of-bounds
//            // position results in a panic, so stop now.
//            return Some(blocked);
//        }
//
//        let mut found_blocker = false;
//
//        // if moving into a blocked tile, we are blocked
//        if self[end_pos].does_tile_block(blocked_type) {
//            blocked.blocked_tile = true;
//            found_blocker = true;
//        }
//
//        let (x, y) = (start_pos.x, start_pos.y);
//        let move_dir = sub_pos(end_pos, Pos::new(x, y));
//
//        // used for diagonal movement checks
//        let x_moved = Pos::new(end_pos.x, y);
//        let y_moved = Pos::new(x, end_pos.y);
//
//        let direction = Direction::from_dxy(move_dir.x, move_dir.y).unwrap();
//        match direction {
//            Direction::Right | Direction::Left => {
//                let mut left_wall_pos = start_pos;
//                if move_dir.x >= 1 {
//                    left_wall_pos = Pos::new(x + move_dir.x, y);
//                }
//
//                if self.is_within_bounds(left_wall_pos) &&
//                   blocked_type.blocking(self[left_wall_pos].left_wall, self[left_wall_pos].left_material) {
//                        blocked.wall_type = self[left_wall_pos].left_wall;
//                        found_blocker = true;
//                }
//            }
//
//            Direction::Up | Direction::Down => {
//                let mut bottom_wall_pos = Pos::new(x, y + move_dir.y);
//                if move_dir.y >= 1 {
//                    bottom_wall_pos = start_pos;
//                }
//
//                if self.is_within_bounds(bottom_wall_pos) &&
//                   blocked_type.blocking(self[bottom_wall_pos].bottom_wall, self[bottom_wall_pos].bottom_material) {
//                        blocked.wall_type = self[bottom_wall_pos].bottom_wall;
//                        found_blocker = true;
//                }
//            }
//
//            Direction::DownRight => {
//                if self.blocked_right(start_pos, blocked_type) && self.blocked_down(start_pos, blocked_type) {
//                    blocked.wall_type = self[start_pos].bottom_wall;
//                    found_blocker = true;
//                }
//
//                if self.blocked_right(move_y(start_pos, 1), blocked_type) &&
//                   self.blocked_down(move_x(start_pos, 1), blocked_type) {
//                    let blocked_pos = add_pos(start_pos, Pos::new(1, 0));
//                    if self.is_within_bounds(blocked_pos) {
//                        blocked.wall_type = self[blocked_pos].bottom_wall;
//                    }
//                    found_blocker = true;
//                }
//
//                if self.blocked_right(start_pos, blocked_type) &&
//                   self.blocked_right(y_moved, blocked_type) {
//                    let blocked_pos = move_x(start_pos, 1);
//                    if self.is_within_bounds(blocked_pos) {
//                        blocked.wall_type = self[blocked_pos].left_wall;
//                    }
//                    found_blocker = true;
//                }
//
//                if self.blocked_down(start_pos, blocked_type) &&
//                   self.blocked_down(x_moved, blocked_type) {
//                    blocked.wall_type = self[start_pos].bottom_wall;
//                    found_blocker = true;
//                }
//            }
//
//            Direction::UpRight => {
//                if self.blocked_up(start_pos, blocked_type) && self.blocked_right(start_pos, blocked_type) {
//                    let blocked_pos = move_y(start_pos, -1);
//                    if self.is_within_bounds(blocked_pos) {
//                        blocked.wall_type = self[blocked_pos].bottom_wall;
//                    }
//                    found_blocker = true;
//                }
//
//                if self.blocked_up(move_x(start_pos, 1), blocked_type) &&
//                   self.blocked_right(move_y(start_pos, -1), blocked_type) {
//                    let blocked_pos = add_pos(start_pos, Pos::new(1, -1));
//                    if self.is_within_bounds(blocked_pos) {
//                        blocked.wall_type = self[blocked_pos].bottom_wall;
//                    }
//                    found_blocker = true;
//                }
//
//                if self.blocked_right(start_pos, blocked_type) && self.blocked_right(y_moved, blocked_type) {
//                    let blocked_pos = move_x(start_pos, 1);
//                    if self.is_within_bounds(blocked_pos) {
//                        blocked.wall_type = self[blocked_pos].left_wall;
//                    }
//                    found_blocker = true;
//                }
//
//                if self.blocked_up(start_pos, blocked_type) && self.blocked_up(x_moved, blocked_type) {
//                    let blocked_pos = move_y(start_pos, -1);
//                    if self.is_within_bounds(blocked_pos) {
//                        blocked.wall_type = self[blocked_pos].bottom_wall;
//                    }
//                    found_blocker = true;
//                }
//            }
//
//            Direction::DownLeft => {
//                if self.blocked_left(start_pos, blocked_type) && self.blocked_down(start_pos, blocked_type) {
//                    blocked.wall_type = self[start_pos].left_wall;
//                    found_blocker = true;
//                }
//
//                if self.blocked_left(move_y(start_pos, 1), blocked_type) &&
//                   self.blocked_down(move_x(start_pos, -1), blocked_type) {
//                    let blocked_pos = add_pos(start_pos, Pos::new(-1, 1));
//                    if self.is_within_bounds(blocked_pos) {
//                        blocked.wall_type = self[blocked_pos].left_wall;
//                    }
//                    found_blocker = true;
//                }
//
//                if self.blocked_left(start_pos, blocked_type) && self.blocked_left(y_moved, blocked_type) {
//                    blocked.wall_type = self[start_pos].left_wall;
//                    found_blocker = true;
//                }
//
//                if self.blocked_down(start_pos, blocked_type) && self.blocked_down(x_moved, blocked_type) {
//                    blocked.wall_type = self[start_pos].bottom_wall;
//                    found_blocker = true;
//                }
//            }
//
//            Direction::UpLeft => {
//                if self.blocked_left(move_y(start_pos, -1), blocked_type) &&
//                   self.blocked_up(move_x(start_pos, -1), blocked_type) {
//                    let blocked_pos = add_pos(start_pos, Pos::new(-1, -1));
//                    if self.is_within_bounds(blocked_pos) {
//                        blocked.wall_type = self[blocked_pos].left_wall;
//                    }
//                    found_blocker = true;
//                }
//
//                if self.blocked_left(start_pos, blocked_type) && self.blocked_up(start_pos, blocked_type) {
//                    blocked.wall_type = self[start_pos].left_wall;
//                    found_blocker = true;
//                }
//
//                if self.blocked_left(start_pos, blocked_type) && self.blocked_left(y_moved, blocked_type) {
//                    blocked.wall_type = self[start_pos].left_wall;
//                    found_blocker = true;
//                }
//
//                if self.blocked_up(start_pos, blocked_type) && self.blocked_up(x_moved, blocked_type) {
//                    let blocked_pos = move_y(start_pos, -1);
//                    if self.is_within_bounds(blocked_pos) {
//                        blocked.wall_type = self[blocked_pos].bottom_wall;
//                    }
//                    found_blocker = true;
//                }
//            }
//        }
//
//        if found_blocker {
//            return Some(blocked);
//        } else {
//            return None;
//        }
//    }
//
//    pub fn path_blocked(&self, start_pos: Pos, end_pos: Pos, blocked_type: BlockedType) -> Option<Blocked> {
//        let line = line(start_pos, end_pos);
//        let positions = iter::once(start_pos).chain(line.into_iter());
//        for (pos, target_pos) in positions.tuple_windows() {
//            let blocked = self.move_blocked(pos, target_pos, blocked_type);
//            if blocked.is_some() {
//                return blocked;
//            }
//        }
//
//        return None;
//    }
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
//        return self.left_wall != Wall::Empty && self.left_material != Surface::Grass;
//    }
//
//    pub fn does_down_block(&self) -> bool {
//        return self.bottom_wall != Wall::Empty && self.bottom_material != Surface::Grass;
//    }
//
//#[derive(Clone, Copy, PartialEq, Eq, Ord, PartialOrd, Debug)]
//pub enum Rotation {
//    Degrees0,
//    Degrees90,
//    Degrees180,
//    Degrees270,
//}
//
//impl Rotation {
//    pub fn rotate(&self, pos: Pos, width: i32, height: i32) -> Pos {
//        let mut result = pos;
//        match self {
//            Rotation::Degrees0 => {
//            }
//            Rotation::Degrees90 => {
//                // 90 degrees: swap x and y, mirror in x
//                result = Pos::new(result.y, result.x);
//                result = mirror_in_x(result, width);
//            }
//            Rotation::Degrees180 => {
//                // 180 degrees: mirror in x, mirror in y
//                result = mirror_in_x(result, width);
//                result = mirror_in_y(result, height);
//            }
//            Rotation::Degrees270 => {
//                // 270: swap x and y, mirror in y
//                result = Pos::new(result.y, result.x);
//                result = mirror_in_y(result, height);
//            }
//        }
//
//        return result;
//    }
//}
//
//#[test]
//fn test_rotation() {
//    let pos = Pos::new(0, 0);
//    let width = 10;
//    let height = 20;
//
//    assert_eq!(pos, Rotation::Degrees0.rotate(pos, width, height));
//    assert_eq!(Pos::new(width - 1, 0), Rotation::Degrees90.rotate(pos, width, height));
//    assert_eq!(Pos::new(width - 1, height - 1), Rotation::Degrees180.rotate(pos, width, height));
//    assert_eq!(Pos::new(0, height - 1), Rotation::Degrees270.rotate(pos, width, height));
//}
//
//pub fn reorient_map(map: &Map, rotation: Rotation, mirror: bool) -> Map {
//    let (width, height) = map.size();
//
//    let (mut new_width, mut new_height) = (width, height);
//    if rotation == Rotation::Degrees90 || rotation == Rotation::Degrees270 {
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
//                pos = mirror_in_x(pos, width);
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
//                let new_wall_pos = move_x(wall_pos, 1);
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
//                let new_wall_pos = move_x(wall_pos, 1);
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

