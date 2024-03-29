const std = @import("std");
const BoundedArray = std.BoundedArray;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const Dims = math.utils.Dims;

const utils = @import("utils");

const Tile = @import("tile.zig").Tile;
const blocking = @import("blocking.zig");

pub const Map = struct {
    width: i32,
    height: i32,
    tiles: []Tile,
    allocator: Allocator,

    pub fn empty(allocator: Allocator) Map {
        return Map{ .width = 0, .height = 0, .tiles = &.{}, .allocator = allocator };
    }

    pub fn fromSlice(tiles: []Tile, width: i32, height: i32, allocator: Allocator) Map {
        return Map{ .tiles = tiles, .width = width, .height = height, .allocator = allocator };
    }

    pub fn fromDims(width: i32, height: i32, allocator: Allocator) !Map {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        var tiles = try allocator.alloc(Tile, @intCast(usize, width * height));
        std.mem.set(Tile, tiles, Tile.empty());
        return Map.fromSlice(tiles, width, height, allocator);
    }

    pub fn get(self: *const Map, position: Pos) Tile {
        const index = position.x + position.y * self.width;
        return self.tiles[@intCast(usize, index)];
    }

    pub fn getPtr(self: *Map, position: Pos) *Tile {
        const index = position.x + position.y * self.width;
        return &self.tiles[@intCast(usize, index)];
    }

    pub fn set(self: *Map, position: Pos, tile: Tile) void {
        const index = position.x + position.y * self.width;
        self.tiles[@intCast(usize, index)] = tile;
    }

    pub fn isWithinBounds(self: *const Map, position: Pos) bool {
        const x_bounds = position.x >= 0 and position.x < self.width;
        const y_bounds = position.y >= 0 and position.y < self.height;
        return x_bounds and y_bounds;
    }

    pub fn deinit(self: *Map) void {
        self.allocator.free(self.tiles);
    }

    pub fn printLayers(self: *Map) void {
        std.debug.print("center\n", .{});
        var y: i32 = 0;
        while (y < self.height) : (y += 1) {
            var x: i32 = 0;
            while (x < self.width) : (x += 1) {
                std.debug.print("{c}", .{self.get(Pos.init(x, y)).center.height.chr()});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("left\n", .{});
        y = 0;
        while (y < self.height) : (y += 1) {
            var x: i32 = 0;
            while (x < self.width) : (x += 1) {
                std.debug.print("{c}", .{self.get(Pos.init(x, y)).left.height.chr()});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("down\n", .{});
        y = 0;
        while (y < self.height) : (y += 1) {
            var x: i32 = 0;
            while (x < self.width) : (x += 1) {
                std.debug.print("{c}", .{self.get(Pos.init(x, y)).down.height.chr()});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn clear(self: *Map) void {
        for (self.tiles) |*tile| {
            tile.* = Tile.empty();
        }
    }

    pub fn placeIntertileDir(self: *Map, position: Pos, dir: Direction, wall: Tile.Wall) void {
        if (!self.isWithinBounds(position)) {
            @panic("Position not in bounds!");
        }

        switch (dir) {
            .left => {
                self.getPtr(position).left = wall;
            },

            .down => {
                self.getPtr(position).down = wall;
            },

            .right => {
                const new_pos = dir.offsetPos(position, 1);
                if (!self.isWithinBounds(new_pos)) {
                    @panic("Position not in bounds!");
                }
                self.getPtr(new_pos).left = wall;
            },

            .up => {
                const new_pos = dir.offsetPos(position, 1);
                if (!self.isWithinBounds(new_pos)) {
                    @panic("Position not in bounds!");
                }
                self.getPtr(new_pos).down = wall;
            },

            .upLeft => {
                self.getPtr(position).left = wall;

                const new_pos = Direction.up.offsetPos(position, 1);
                if (!self.isWithinBounds(new_pos)) {
                    @panic("Position not in bounds!");
                }
                self.getPtr(new_pos).down = wall;
            },

            .upRight => {
                const right_pos = Direction.right.offsetPos(position, 1);
                if (!self.isWithinBounds(right_pos)) {
                    @panic("Position not in bounds!");
                }
                self.getPtr(right_pos).left = wall;

                const up_pos = Direction.up.offsetPos(position, 1);
                if (!self.isWithinBounds(up_pos)) {
                    @panic("Position not in bounds!");
                }
                self.getPtr(up_pos).down = wall;
            },

            .downLeft => {
                self.getPtr(position).left = wall;
                self.getPtr(position).down = wall;
            },

            .downRight => {
                self.getPtr(position).down = wall;

                const right_pos = Direction.up.offsetPos(position, 1);
                if (!self.isWithinBounds(right_pos)) {
                    @panic("Position not in bounds!");
                }
                self.getPtr(right_pos).left = wall;
            },
        }
    }

    // compact_chrs is not implemented yet- it won't be needed until communicating maps frequently.
    pub fn chrs(map: Map, allocator: Allocator) !ArrayList(u8) {
        var chars = ArrayList(u8).init(allocator);
        errdefer chars.deinit();
        for (map.tiles) |tile| {
            for (tile.chrs()) |chr| {
                try chars.append(chr);
            }
        }

        return chars;
    }

    pub fn dims(map: *const Map) Dims {
        return Dims.init(@intCast(usize, map.width), @intCast(usize, map.height));
    }

    pub fn fromIndex(map: *const Map, index: usize) Pos {
        return Pos.init(@mod(@intCast(i32, index), map.width), @divFloor(@intCast(i32, index), map.width));
    }

    pub fn neighbors(map: *const Map, pos: Pos) !BoundedArray(Pos, 8) {
        var result = BoundedArray(Pos, 8).init(0) catch unreachable;

        for (Direction.directions()) |dir| {
            const end_pos = dir.offsetPos(pos, 1);
            if (map.isWithinBounds(end_pos)) {
                try result.append(end_pos);
            }
        }

        return result;
    }

    /// Returns an array of positions that are not blocked by any wall.
    /// Note that this considers short walls blocking.
    pub fn reachableNeighbors(map: *const Map, pos: Pos) !BoundedArray(Pos, 8) {
        var result = BoundedArray(Pos, 8).init(0) catch unreachable;

        for (Direction.directions()) |dir| {
            const blocked = blocking.moveBlocked(map, pos, dir, .move);
            if (blocked == null) {
                const end_pos = dir.offsetPos(pos, 1);
                try result.append(end_pos);
            }
        }

        return result;
    }

    pub fn placeIntertileWall(map: *Map, pos: Pos, material: Tile.Material, direction: Direction) void {
        const new_pos = direction.offsetPos(pos, 1);
        const tile_supports_wall = map.isWithinBounds(new_pos) and
            blocking.BlockedType.move.tileBlocks(map.get(new_pos)) == .empty and
            !map.get(pos).impassable;
        if (tile_supports_wall) {
            switch (direction) {
                .left => {
                    if (map.get(pos).left.height == .empty) {
                        map.getPtr(pos).left.height = .short;
                        map.getPtr(pos).left.material = material;
                    }
                },

                .right => {
                    if (map.get(pos).left.height == .empty) {
                        map.getPtr(pos).left.height = .short;
                        map.getPtr(pos).left.material = material;
                    }
                },

                .up => {
                    if (map.get(pos).down.height == .empty) {
                        map.getPtr(pos).down.height = .short;
                        map.getPtr(pos).down.material = material;
                    }
                },

                .down => {
                    if (map.get(pos).down.height == .empty) {
                        map.getPtr(pos).down.height = .short;
                        map.getPtr(pos).down.material = material;
                    }
                },

                else => {
                    std.debug.panic("Placing an intertile wall on a diagonal makes no sense!", .{});
                },
            }
        }
    }
};

// NOTE add these back in if needed
//
//    pub fn pos_in_radius(&self, start: Pos, radius: i32) -> Vec<Pos> {
//        let mut circle_positions = HashSet::new();
//
//        // for each position on the edges of a square around the point, with the
//        // radius as the distance in x/y, add to a set.
//        // duplicates will be removed, leaving only points within the radius.
//        for x in (start.x - radius)..(start.x + radius) {
//            for y in (start.y - radius)..(start.y + radius) {
//                let line = line(start, Pos::new(x, y));
//
//                // get points to the edge of square, filtering for points within the given radius
//                for point in line.into_iter() {
//                    if distance(start, point) < radius {
//                        circle_positions.insert(point);
//                    }
//                }
//            }
//        }
//
//        return circle_positions.iter().map(|pos| *pos).collect();
//    }
//
//    pub fn cardinal_neighbors(&self, pos: Pos) -> SmallVec<[Pos; 4]> {
//        let neighbors = [(1, 0), (0, 1), (-1, 0), (0, -1),];
//
//        let mut result = SmallVec::new();
//        for delta in neighbors.iter() {
//            let new_pos = add_pos(pos, Pos::new(delta.0, delta.1));
//            if self.is_within_bounds(new_pos) {
//                result.append(new_pos);
//            }
//        }
//
//        return result;
//    }
//
//    pub fn reachable_neighbors(&self, pos: Pos) -> SmallVec<[Pos; 8]> {
//        let neighbors = [(1, 0),  (1, 1),  (0, 1),
//                         (-1, 1), (-1, 0), (-1, -1),
//                         (0, -1), (1, -1)];
//
//        let mut result = SmallVec::new();
//
//        for delta in neighbors.iter() {
//            let end_pos = Pos::new(pos.x + delta.0, pos.y + delta.1);
//            if self.path_blocked_move(pos, end_pos).is_none() {
//                result.append(add_pos(pos, Pos::new(delta.0, delta.1)));
//            }
//        }
//
//        return result;
//    }
//
//    pub fn get_all_pos(&self) -> Vec<Pos> {
//        let (width, height) = self.size();
//        return (0..width).cartesian_product(0..height)
//                         .map(|pair| Pos::from(pair))
//                         .collect::<Vec<Pos>>();
//    }
//
//    pub fn get_empty_pos(&self) -> Vec<Pos> {
//        let (width, height) = self.size();
//        return (0..width).cartesian_product(0..height)
//                         .map(|pair| Pos::from(pair))
//                         .filter(|pos| self[*pos].tile_type != TileType::Wall)
//                         .filter(|pos| self[*pos].tile_type != TileType::Water)
//                         .collect::<Vec<Pos>>();
//    }
//
//    pub fn get_wall_pos(&self) -> Vec<Pos> {
//        let (width, height) = self.size();
//        return (0..width).cartesian_product(0..height)
//                         .map(|pair| Pos::from(pair))
//                         .filter(|pos| self[*pos].tile_type == TileType::Wall)
//                         .collect::<Vec<Pos>>();
//    }
//
