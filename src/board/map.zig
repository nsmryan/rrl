const std = @import("std");
const Allocator = std.mem.Allocator;

const pos = @import("utils");
const Pos = pos.Pos;

const Tile = @import("tile").Tile;

pub const Map = struct {
    width: i32,
    height: i32,
    tiles: []Tile,

    // TODO this likely does need to be added back in for performance.
    //fov_cache: std.AutoHashMap(Pos, ArrayList(Pos)),

    pub fn fromSlice(tiles: []Tile, width: i32, height: i32) Map {
        return Map{ .tiles = tiles, .width = width, .height = height };
    }

    pub fn fromDims(width: i32, height: i32, allocator: Allocator) Map {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        var tiles = allocator.alloc(Tile, width * height);
        return Map.fromSlice(tiles, width, height);
    }

    pub fn get(self: *const Map, position: Pos) Tile {
        const index = position.x + position.y * self.width;
        return self.tiles[index];
    }

    pub fn isEmpty(self: *const Map, position: Pos) bool {
        return self.get(position).tile_type == .empty;
    }

    pub fn isWithinBounds(self: *const Map, position: Pos) bool {
        const x_bounds = position.x >= 0 and position.x < self.width;
        const y_bounds = position.y >= 0 and position.y < self.height;
        return x_bounds and y_bounds;
    }

    // TODO add back in when Dims type is available
    //pub fn dims(self: *const Map) Dims

    // TODO continue with map functions are is_in_fov_edge
};
