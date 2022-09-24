//pub fn near_tile_type(map: &Map, position: Pos, tile_type: TileType) -> bool {
//    let neighbor_offsets: Vec<(i32, i32)>
//        = vec!((1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1));
//
//    let mut near_given_tile = false;
//
//    for offset in neighbor_offsets {
//        let offset = Pos::from(offset);
//        let neighbor_position = move_by(position, offset);
//
//        if map.is_within_bounds(neighbor_position) &&
//           map[neighbor_position].tile_type == tile_type {
//            near_given_tile = true;
//            break;
//        }
//    }
//
//    return near_given_tile;
//}
