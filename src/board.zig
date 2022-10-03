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
//
test "board test set" {
    _ = @import("board/blocking.zig");
    _ = @import("board/fov.zig");
    _ = @import("board/map.zig");
    _ = @import("board/pathing.zig");
    _ = @import("board/tile.zig");
    _ = @import("board/rotate.zig");
    _ = @import("board/shadowcasting.zig");
}
