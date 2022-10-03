const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.mem.ArrayList;

const utils = @import("utils");
const Pos = utils.pos.Pos;
const Direction = utils.Direction;

const Tile = @import("tile.zig").Tile;

pub const Map = struct {
    width: i32,
    height: i32,
    tiles: []Tile,

    // TODO this likely does need to be added back in for performance.
    //fov_cache: std.AutoHashMap(Pos, ArrayList(Pos)),

    pub fn fromSlice(tiles: []Tile, width: i32, height: i32) Map {
        return Map{ .tiles = tiles, .width = width, .height = height };
    }

    pub fn fromDims(width: i32, height: i32, allocator: Allocator) !Map {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        var tiles = try allocator.alloc(Tile, @intCast(usize, width * height));
        std.mem.set(Tile, tiles, Tile.empty());
        return Map.fromSlice(tiles, width, height);
    }

    pub fn get(self: *const Map, position: Pos) Tile {
        const index = position.x + position.y * self.width;
        return self.tiles[@intCast(usize, index)];
    }

    pub fn getPtr(self: *Map, position: Pos) *Tile {
        const index = position.x + position.y * self.width;
        return &self.tiles[@intCast(usize, index)];
    }

    pub fn isEmpty(self: *const Map, position: Pos) bool {
        return self.get(position).tile_type == .empty;
    }

    pub fn isWithinBounds(self: *const Map, position: Pos) bool {
        const x_bounds = position.x >= 0 and position.x < self.width;
        const y_bounds = position.y >= 0 and position.y < self.height;
        return x_bounds and y_bounds;
    }

    pub fn deinit(self: *Map, allocator: Allocator) void {
        allocator.free(self.tiles);
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
    pub fn chrs(map: Map, allocator: Allocator) ArrayList(u8) {
        var chars = ArrayList(u8).init(allocator);
        for (map.tiles) |tile| {
            for (tile.chrs()) |chr| {
                chars.append(chr);
            }
        }
        return chars;
    }

    // TODO add back in when Dims type is available
    //pub fn dims(self: *const Map) Dims

    // TODO continue with map functions are is_in_fov_edge
};
