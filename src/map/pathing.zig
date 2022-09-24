//    pub fn does_tile_block(self, block_type: BlockedType) -> bool {
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
