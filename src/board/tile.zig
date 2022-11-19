pub const Tile = struct {
    /// Is the tile part of the game (aka not a 'water' tile).
    impassable: bool,
    center: Wall,
    down: Wall,
    left: Wall,

    pub const Wall = struct {
        height: Height,
        material: Material,

        pub fn init(height: Height, material: Material) Wall {
            return Wall{ .height = height, .material = material };
        }

        pub fn empty() Wall {
            return Wall{ .height = .empty, .material = .stone };
        }

        pub fn short() Wall {
            return Wall{ .height = .short, .material = .stone };
        }

        pub fn tall() Wall {
            return Wall{ .height = .tall, .material = .stone };
        }
    };

    pub const Material = enum(u8) {
        stone,
        rubble,
        grass,

        pub fn chr(self: Material) u8 {
            return switch (self) {
                .stone => 'f',
                .rubble => 'r',
                .grass => 'g',
            };
        }
    };

    pub const Height = enum(u8) {
        empty,
        short,
        tall,

        pub fn noWall(self: Height) bool {
            return switch (self) {
                .empty => true,
                .short => false,
                .tall => false,
            };
        }

        pub fn join(self: Height, other: Height) Height {
            if (self == .tall or other == .tall) {
                return .tall;
            } else if (self == .short or other == .short) {
                return .short;
            } else {
                return .empty;
            }
        }

        pub fn meet(self: Height, other: Height) Height {
            if (self == .empty or other == .empty) {
                return .empty;
            } else if (self == .short or other == .short) {
                return .short;
            } else {
                return self.join(other);
            }
        }

        pub fn chr(self: Height) u8 {
            return switch (self) {
                .empty => 'e',
                .short => 's',
                .tall => 't',
            };
        }
    };

    pub fn init(center: Wall, down: Wall, left: Wall) Tile {
        return Tile{ .impassable = false, .center = center, .down = down, .left = left };
    }

    pub fn impassable() Tile {
        return Tile{ .impassable = true, .center = Wall.empty(), .down = Wall.empty(), .left = Wall.empty() };
    }

    pub fn empty() Tile {
        return Tile.init(Wall.empty(), Wall.empty(), Wall.empty());
    }

    pub fn shortDownWall() Tile {
        var tile = Tile.empty();
        tile.down.height = Height.short;
        return tile;
    }

    pub fn shortLeftWall() Tile {
        var tile = Tile.empty();
        tile.left.height = Height.short;
        return tile;
    }

    pub fn shortLeftAndDownWall() Tile {
        var tile = Tile.empty();
        tile.down.height = Height.short;
        tile.left.height = Height.short;
        return tile;
    }

    pub fn grass() Tile {
        var tile = Tile.empty();
        tile.center.material = Material.grass;
        return tile;
    }

    pub fn tallGrass() Tile {
        var tile = Tile.empty();
        tile.center.material = Material.grass;
        tile.center.height = Height.tall;
        return tile;
    }

    pub fn rubble() Tile {
        var tile = Tile.empty();
        tile.center.material = Material.rubble;
        return tile;
    }

    pub fn tallWall() Tile {
        var tile = Tile.empty();
        tile.center.height = .tall;
        return tile;
    }

    pub fn shortWall() Tile {
        var tile = Tile.empty();
        tile.center.height = .short;
        return tile;
    }

    pub fn clearWalls(self: *Tile) void {
        self.center.height = .empty;
        self.center.material = Material.stone;
        self.down.height = .empty;
        self.down.material = Material.stone;
        self.left.height = .empty;
        self.left.material = Material.stone;
    }

    pub fn chrs(self: Tile) [7]u8 {
        var chars: [7]u8 = undefined;
        var index: usize = 0;

        if (self.impassable) {
            chars[index] = '1';
        } else {
            chars[index] = '0';
        }
        index += 1;

        chars[index] = self.center.height.chr();
        index += 1;

        chars[index] = self.center.material.chr();
        index += 1;

        chars[index] = self.left.height.chr();
        index += 1;

        chars[index] = self.left.material.chr();
        index += 1;

        chars[index] = self.down.height.chr();
        index += 1;

        chars[index] = self.down.material.chr();

        return chars;
    }
};

// Tiles are currently a two byte type. This may change in the future, but this
// test makes sure that the size is known.
// NOTE packing Tile, with bit sized enums for height and material, seems to cause some crashes.
// Maybe try this again later
//test "tile type bit size" {
//    const std = @import("std");
//    try std.testing.expectEqual(2, @sizeOf(Tile));
//}
