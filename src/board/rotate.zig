const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const math = @import("math");
const Pos = math.pos.Pos;

const tile = @import("tile.zig");
const Tile = tile.Tile;
const Material = Tile.Material;
const Wall = Tile.Wall;

const Map = @import("map.zig").Map;

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

const RotatePair = struct {
    pos: Pos,
    wall: Wall,
};

pub fn reorientMap(map: Map, rotation: Rotation, mirror: bool, allocator: Allocator) !Map {
    var new_width = map.width;
    var new_height = map.height;

    if (rotation == Rotation.degrees90 or rotation == Rotation.degrees270) {
        new_width = map.height;
        new_height = map.width;
    }
    var new_map = try Map.fromDims(@intCast(i32, new_width), @intCast(i32, new_height), allocator);

    var left_walls = ArrayList(RotatePair).init(allocator);
    defer left_walls.deinit();

    var down_walls = ArrayList(RotatePair).init(allocator);
    defer down_walls.deinit();

    // Move tiles to their new, rotated, position.
    // This keeps track of the inter-tile wall information from the original tiles, so
    // these can also be rotated for the new position.
    var x: i32 = 0;
    while (x < map.width) : (x += 1) {
        var y: i32 = 0;
        while (y < map.height) : (y += 1) {
            const orig_pos = Pos.init(x, y);

            var new_pos = Pos.init(x, y);
            if (mirror) {
                new_pos = new_pos.mirrorInX(map.width);
            }
            new_pos = rotation.rotate(new_pos, new_width, new_height);
            new_map.getPtr(new_pos).* = map.get(orig_pos);

            if (!std.meta.eql(map.get(orig_pos).left, Wall.empty())) {
                try left_walls.append(RotatePair{ .pos = new_pos, .wall = map.get(orig_pos).left });
            }

            if (!std.meta.eql(map.get(orig_pos).down, Wall.empty())) {
                try down_walls.append(RotatePair{ .pos = new_pos, .wall = map.get(orig_pos).down });
            }
        }
    }

    //// Clear all inter-tile walls so we can fill them back in with their rotated versions.
    x = 0;
    while (x < new_width) : (x += 1) {
        var y: i32 = 0;
        while (y < new_height) : (y += 1) {
            const new_pos = Pos.init(x, y);
            const empty_wall = Wall.empty();
            new_map.getPtr(new_pos).left = empty_wall;
            new_map.getPtr(new_pos).down = empty_wall;
        }
    }

    // Fill in the previously left side inter-tile wall.
    for (left_walls.items) |pair| {
        switch (rotation) {
            Rotation.degrees0 => {
                new_map.getPtr(pair.pos).left = pair.wall;
            },

            Rotation.degrees90 => {
                const new_wall_pos = pair.pos.moveY(-1);
                if (new_map.isWithinBounds(new_wall_pos)) {
                    new_map.getPtr(new_wall_pos).down = pair.wall;
                }
            },

            Rotation.degrees180 => {
                const new_wall_pos = pair.pos.moveX(1);
                if (new_map.isWithinBounds(new_wall_pos)) {
                    new_map.getPtr(new_wall_pos).left = pair.wall;
                }
            },

            Rotation.degrees270 => {
                new_map.getPtr(pair.pos).down = pair.wall;
            },
        }
    }

    // Fill in the previously down side inter-tile wall.
    for (down_walls.items) |pair| {
        switch (rotation) {
            Rotation.degrees0 => {
                new_map.getPtr(pair.pos).down = pair.wall;
            },

            Rotation.degrees90 => {
                new_map.getPtr(pair.pos).left = pair.wall;
            },

            Rotation.degrees180 => {
                const new_wall_pos = pair.pos.moveY(-1);
                if (new_map.isWithinBounds(new_wall_pos)) {
                    new_map.getPtr(new_wall_pos).down = pair.wall;
                }
            },

            Rotation.degrees270 => {
                const new_wall_pos = pair.pos.moveX(1);
                if (new_map.isWithinBounds(new_wall_pos)) {
                    new_map.getPtr(new_wall_pos).left = pair.wall;
                }
            },
        }
    }

    return new_map;
}

test "reorient map 0" {
    var allocator = std.testing.allocator;

    var map = try Map.fromDims(5, 5, allocator);
    defer map.deinit();

    const short_wall = Wall.init(Tile.Height.short, Tile.Material.stone);
    map.getPtr(Pos.init(1, 0)).* = Tile.shortLeftWall();
    map.getPtr(Pos.init(1, 1)).* = Tile.shortLeftWall();
    map.getPtr(Pos.init(1, 2)).* = Tile.init(Wall.empty(), short_wall, short_wall);

    var new_map = try reorientMap(map, Rotation.degrees0, false, allocator);
    defer new_map.deinit();

    try std.testing.expectEqual(Tile.shortLeftWall(), new_map.get(Pos.init(1, 0)));
    try std.testing.expectEqual(Tile.shortLeftWall(), new_map.get(Pos.init(1, 1)));
    try std.testing.expectEqual(Tile.shortLeftAndDownWall(), new_map.get(Pos.init(1, 2)));
}

test "reorient map 90" {
    var allocator = std.testing.allocator;

    var map = try Map.fromDims(5, 5, allocator);
    defer map.deinit();

    const short_wall = Wall.init(Tile.Height.short, Tile.Material.stone);
    map.getPtr(Pos.init(1, 0)).* = Tile.shortLeftWall();
    map.getPtr(Pos.init(1, 1)).* = Tile.shortLeftWall();
    map.getPtr(Pos.init(1, 2)).* = Tile.init(Wall.empty(), short_wall, short_wall);

    var new_map = try reorientMap(map, Rotation.degrees90, false, allocator);
    defer new_map.deinit();

    try std.testing.expectEqual(Tile.shortLeftWall(), new_map.get(Pos.init(2, 1)));
    try std.testing.expectEqual(Tile.shortDownWall(), new_map.get(Pos.init(2, 0)));
    try std.testing.expectEqual(Tile.shortDownWall(), new_map.get(Pos.init(3, 0)));
    try std.testing.expectEqual(Tile.shortDownWall(), new_map.get(Pos.init(4, 0)));
}

test "reorient map 180" {
    var allocator = std.testing.allocator;

    var map = try Map.fromDims(5, 5, allocator);
    defer map.deinit();

    const short_wall = Wall.init(Tile.Height.short, Tile.Material.stone);
    map.getPtr(Pos.init(1, 0)).* = Tile.shortLeftWall();
    map.getPtr(Pos.init(1, 1)).* = Tile.shortLeftWall();
    map.getPtr(Pos.init(1, 2)).* = Tile.init(Wall.empty(), short_wall, short_wall);

    var new_map = try reorientMap(map, Rotation.degrees180, false, allocator);
    defer new_map.deinit();

    try std.testing.expectEqual(Tile.shortDownWall(), new_map.get(Pos.init(3, 1)));
    try std.testing.expectEqual(Tile.shortLeftWall(), new_map.get(Pos.init(4, 2)));
    try std.testing.expectEqual(Tile.shortLeftWall(), new_map.get(Pos.init(4, 3)));
    try std.testing.expectEqual(Tile.shortLeftWall(), new_map.get(Pos.init(4, 4)));
}

test "reorient map 270" {
    var allocator = std.testing.allocator;

    var map = try Map.fromDims(5, 5, allocator);
    defer map.deinit();

    const short_wall = Wall.init(Tile.Height.short, Tile.Material.stone);
    map.getPtr(Pos.init(1, 0)).* = Tile.shortLeftWall();
    map.getPtr(Pos.init(1, 1)).* = Tile.shortLeftWall();
    map.getPtr(Pos.init(1, 2)).* = Tile.init(Wall.empty(), short_wall, short_wall);

    var new_map = try reorientMap(map, Rotation.degrees270, false, allocator);
    defer new_map.deinit();

    try std.testing.expectEqual(Tile.shortDownWall(), new_map.get(Pos.init(0, 3)));
    try std.testing.expectEqual(Tile.shortDownWall(), new_map.get(Pos.init(1, 3)));
    try std.testing.expectEqual(Tile.shortDownWall(), new_map.get(Pos.init(2, 3)));
    try std.testing.expectEqual(Tile.shortLeftWall(), new_map.get(Pos.init(3, 3)));
}
