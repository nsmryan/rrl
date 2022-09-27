pub const Tile = struct {
    explored: bool,
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
    };

    pub const Material = enum {
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

    pub const Height = enum {
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

        pub fn chr(self: Height) u8 {
            return switch (self) {
                .empty => 'e',
                .short => 's',
                .tall => 't',
            };
        }
    };

    pub fn init(wall: Wall, down: Wall, left: Wall) Tile {
        return Tile{ .explored = false, .impassable = false, .wall = wall, .down = down, .left = left };
    }

    pub fn impassable() Tile {
        return Tile{ .explored = false, .impassable = false, .wall = Wall.empty(), .down = Wall.empty(), .left = Wall.empty() };
    }

    pub fn empty() Tile {
        return Tile.init(Wall.empty(), Wall.empty(), Wall.empty());
    }

    pub fn shortDownWall() Tile {
        var tile = Tile.empty();
        tile.down.wall = Wall.short;
        return tile;
    }

    pub fn shortLeftWall() Tile {
        var tile = Tile.empty();
        tile.left.wall = Wall.short;
        return tile;
    }

    pub fn shortLeftAndDownWall() Tile {
        var tile = Tile.empty();
        tile.down.wall = Wall.short;
        tile.left.wall = Wall.short;
        return tile;
    }

    pub fn grass() Tile {
        var tile = Tile.empty();
        tile.material = Material.grass;
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
        tile.material = Material.rubbble;
        return tile;
    }

    pub fn tallWall() Tile {
        var tile = Tile.empty();
        tile.wall.height = .tall;
    }

    pub fn shortWall() Tile {
        var tile = Tile.empty();
        tile.wall.height = .short;
    }

    pub fn clearWalls(self: *Tile) void {
        self.wall.height = .empty;
        self.wall.material = Material.stone;
        self.down.height = .empty;
        self.down.material = Material.stone;
        self.left.height = .empty;
        self.left.material = Material.stone;
    }

    pub fn chrs(self: Tile) [8]u8 {
        var chars: [8]u8 = undefined;
        var index = 0;

        if (self.explored) {
            chars[index] = '1';
        } else {
            chars[index] = '0';
        }
        index += 1;

        if (self.impassable) {
            chars[index] = '1';
        } else {
            chars[index] = '0';
        }
        index += 1;

        chars[index] = self.wall.height.chr();
        index += 1;

        chars[index] = self.wall.material.chr();
        index += 1;

        chars[index] = self.left.height.chr();
        index += 1;

        chars[index] = self.left.material.chr();

        chars[index] = self.down.height.chr();
        index += 1;

        chars[index] = self.down.material.chr();

        return chars;
    }
};
