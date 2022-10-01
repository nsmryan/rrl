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
//        return self.left.wall != Wall::Empty && self.left_material != Material::Grass;
//    }
//
//    pub fn does_down_block(&self) -> bool {
//        return self.down_wall != Wall::Empty && self.bottom_material != Material::Grass;
//    }
//
