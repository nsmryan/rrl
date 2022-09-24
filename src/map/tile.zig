pub const Tile = struct {
    block_move: bool,
    block_sight: bool,
    explored: bool,
    tile_type: Type,
    surface: Surface,
    down: InterTileWall,
    left: InterTileWall,

    pub const InterTileWall = struct {
        wall: Wall,
        surface: Surface,

        pub fn init(wall: Wall, surface: Surface) InterTileWall {
            return InterTileWall{ .wall = wall, .surface = surface };
        }
    };

    pub const Surface = enum {
        floor,
        rubble,
        grass,

        pub fn chr(self: Surface) u8 {
            return switch (self) {
                .floor => 'f',
                .rubble => 'r',
                .grass => 'g',
            };
        }
    };

    pub const Type = enum {
        empty,
        shortWall,
        wall,
        water,
        exit,

        pub fn isWall(self: Type) bool {
            return switch (self) {
                .shortWall | .wall => return true,
                else => return false,
            };
        }

        pub fn char(self: Type) u8 {
            return switch (self) {
                .empty => 'e',
                .shortWall => 's',
                .wall => 'w',
                .water => 'a',
                .exit => 'x',
            };
        }
    };

    pub const Wall = enum {
        empty,
        shortWall,
        tallWall,

        pub fn noWall(self: Wall) bool {
            return switch (self) {
                .empty => true,
                .shortWall => false,
                .tallWall => false,
            };
        }

        pub fn chr(self: Wall) u8 {
            return switch (self) {
                .empty => 'e',
                .shortWall => 's',
                .tallWall => 't',
            };
        }
    };

    pub fn init(block_move: bool, block_sight: bool, explored: bool, tile_type: Type, surface: Surface, down: InterTileWall, left: InterTileWall) Tile {
        return Tile{ .block_move = block_move, .block_sight = block_sight, .explored = explored, .tile_type = tile_type, .surface = surface, .down = down, .left = left };
    }

    pub fn empty() Tile {
        return Tile.init(false, false, false, Type.empty, Surface.floor, InterTileWall.init(Wall.empty, Surface.floor), InterTileWall.init(Wall.empty, Surface.floor));
    }

    pub fn shortDownWall() Tile {
        var tile = Tile.empty();
        tile.down.wall = Wall.shortWall;
        return tile;
    }

    pub fn shortLeftWall() Tile {
        var tile = Tile.empty();
        tile.left.wall = Wall.shortWall;
        return tile;
    }

    pub fn shortLeftAndDownWall() Tile {
        var tile = Tile.empty();
        tile.down.wall = Wall.shortWall;
        tile.left.wall = Wall.shortWall;
        return tile;
    }

    pub fn water() Tile {
        var tile = Tile.empty();
        tile.block_move = true;
        tile.tile_type = Type.water;
        return tile;
    }

    pub fn grass() Tile {
        var tile = Tile.empty();
        tile.surface = Surface.grass;
        return tile;
    }

    pub fn tallGrass() Tile {
        var tile = Tile.empty();
        tile.block_sight = true;
        tile.surface = Surface.grass;
        return tile;
    }

    pub fn rubble() Tile {
        var tile = Tile.empty();
        tile.surface = Surface.rubbble;
        return tile;
    }

    pub fn wall() Tile {
        var tile = Tile.empty();
        tile.block_move = true;
        tile.block_sight = true;
        tile.tile_type = Type.wall;
    }

    pub fn shortWall() Tile {
        var tile = Tile.empty();
        // NOTE(correctness) is it correct for short walls to not block movement like this?
        tile.block_move = false;
        tile.block_sight = true;
        tile.tile_type = Type.shortWall;
    }

    pub fn clearWalls(self: *Tile) void {
        self.block_move = false;
        self.block_sight = false;
        self.down.wall = Wall.empty;
        self.down.surface = Surface.floor;
        self.left.wall = Wall.empty;
        self.left.surface = Surface.floor;
        self.surface = Surface.floor;
    }

    pub fn exit() Tile {
        var tile = Tile.empty();
        tile.tile_type = Type.exit;
        return tile;
    }

    pub fn shorten(self: *Tile) void {
        if (self.down.wall == Wall.tallWall) {
            self.down.wall = Wall.shortWall;
        }

        if (self.left.wall == Wall.tallWall) {
            self.left.wall = Wall.shortWall;
        }
    }

    pub fn chrs(self: Tile) [8]u8 {
        var chrs: [8]u8;
        var index = 0;
        if (self.block_move) {
            chrs[index] = '1';
        } else {
            chrs[index] = '0';
        }
        index += 1;

        if (self.block_sight) {
            chrs[index] = '1';
        } else {
            chrs[index] = '0';
        }
        index += 1;

        chrs[index] = self.tile_type.chr();
        index += 1;

        chrs[index] = self.down.wall.chr();
        index += 1;

        chrs[index] = self.down.surface.chr();
        index += 1;

        chrs[index] = self.left.wall.chr();
        index += 1;

        chrs[index] = self.left.surface.chr();
        index += 1;

        chrs[index] = self.surface.chr();

        return chrs;
    }
};
