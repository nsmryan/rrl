const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

const engine = @import("engine");
const Game = engine.game.Game;

const core = @import("core");
const Entities = core.entities.Entities;

const board = @import("board");
const Tile = board.tile.Tile;

const math = @import("math");
const Pos = math.pos.Pos;
const Color = math.utils.Color;

const drawcmd = @import("drawcmd");
const DrawCmd = drawcmd.drawcmd.DrawCmd;
const Panel = drawcmd.panel.Panel;
const Sprites = drawcmd.sprite.Sprites;
const Sprite = drawcmd.sprite.Sprite;
const SpriteSheet = drawcmd.sprite.SpriteSheet;

pub fn render(game: *Game, sprites: *const ArrayList(SpriteSheet), panel: *const Panel, drawcmds: *ArrayList(DrawCmd)) !void {
    _ = panel;

    try renderMapLow(game, sprites, drawcmds);
    try renderMapMiddle(game, sprites, drawcmds);
    try renderEntities(game, sprites, drawcmds);
    // TODO render map upper level with down walls and FoV darkening
    //try renderMapHigh(game, sprites, drawcmds);
}

fn renderMapLow(game: *Game, sprites: *const ArrayList(SpriteSheet), drawcmds: *ArrayList(DrawCmd)) !void {
    const open_tile_sprite = try drawcmd.sprite.lookupSingleSprite(sprites, "open_tile");

    var y: i32 = 0;
    while (y < game.level.map.height) : (y += 1) {
        var x: i32 = 0;
        while (x < game.level.map.width) : (x += 1) {
            const pos = Pos.init(x, y);
            const tile = game.level.map.get(pos);
            if (tile.center.material == Tile.Material.stone) {
                try drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.black(), pos));
            }
        }
    }
}

fn renderEntities(game: *Game, sprites: *const ArrayList(SpriteSheet), drawcmds: *ArrayList(DrawCmd)) !void {
    const pos = game.level.entities.pos.get(Entities.player_id).?;
    const player_sprite = try drawcmd.sprite.lookupSingleSprite(sprites, "player_standing_right");
    try drawcmds.append(DrawCmd.sprite(player_sprite, Color.black(), pos));
}

// TODO render left right and upper intertile walls
fn renderMapMiddle(game: *Game, sprites: *const ArrayList(SpriteSheet), drawcmds: *ArrayList(DrawCmd)) !void {
    const wall_sprite = try drawcmd.sprite.lookupSingleSprite(sprites, "horizontal_wall");

    var y: i32 = 0;
    while (y < game.level.map.height) : (y += 1) {
        var x: i32 = 0;
        while (x < game.level.map.width) : (x += 1) {
            const pos = Pos.init(x, y);
            const tile = game.level.map.get(pos);

            // TODO render wall shadows
            //renderWallShadow

            if (tile.center.height == .tall) {
                try drawcmds.append(DrawCmd.sprite(wall_sprite, Color.black(), pos));
            }
            try renderIntertileWalls(pos, game, sprites, drawcmds);
        }
    }
}

fn renderIntertileWalls(pos: Pos, game: *Game, sprites: *const ArrayList(SpriteSheet), drawcmds: *ArrayList(DrawCmd)) !void {
    const tile = game.level.map.get(pos);
    const wall_color = Color.black();

    // Left walls
    if (try intertileSprite(tile.left, "left_intertile_wall", "left_intertile_grass_wall", sprites)) |sprite| {
        try drawcmds.append(DrawCmd.sprite(sprite, wall_color, pos));
    }

    // Right walls
    const right_pos = pos.moveX(1);
    if (game.level.map.isWithinBounds(right_pos)) {
        const right_tile = game.level.map.get(right_pos);

        if (try intertileSprite(right_tile.left, "right_intertile_wall", "right_intertile_grass_wall", sprites)) |sprite| {
            try drawcmds.append(DrawCmd.sprite(sprite, wall_color, pos));
        }
    }

    // Lower walls not handled as they are drawn above other tiles in render_map_above

    // Upper walls
    const up_pos = pos.moveY(-1);
    if (game.level.map.isWithinBounds(up_pos)) {
        const up_tile = game.level.map.get(up_pos);

        if (try intertileSprite(up_tile.down, "up_intertile_wall", "up_intertile_grass_wall", sprites)) |sprite| {
            try drawcmds.append(DrawCmd.sprite(sprite, wall_color, pos));
        }
    }
}

fn intertileSprite(wall: Tile.Wall, stone_name: []const u8, grass_name: []const u8, sprites: *const ArrayList(SpriteSheet)) !?Sprite {
    const shortGrassWall = Tile.Wall.init(.short, .grass);
    const shortStoneWall = Tile.Wall.init(.short, .stone);
    const emptyWall = Tile.Wall.init(.empty, .stone);

    if (std.meta.eql(wall, shortGrassWall)) {
        return try drawcmd.sprite.lookupSingleSprite(sprites, grass_name);
    } else if (std.meta.eql(wall, shortStoneWall)) {
        return try drawcmd.sprite.lookupSingleSprite(sprites, stone_name);
    } else if (!std.meta.eql(wall, emptyWall)) {
        // NOTE tall walls and rubble walls are not represented in the tile set.
        unreachable;
    }
    return null;
}

///// Render Wall Shadows (full tile and intertile walls, left and down)
//fn renderWallShadow(panel: &mut Panel, pos: Pos, display_state: &mut DisplayState, sprites: &Vec<SpriteSheet>, shadow_color: Color) {
//    let shadow_sprite_key = lookup_spritekey(sprites, "shadowtiles");
//
//    let tile = display_state.map[pos];
//
//    let (_map_width, map_height) = display_state.map.size();
//    let (x, y) = pos.to_tuple();
//
//    let left_valid = x - 1 > 0;
//    let down_valid = y + 1 < map_height;
//    let down_left_valid = left_valid && down_valid;
//    let left_wall = left_valid && display_state.map[(x - 1, y)].tile_type == TileType::Wall;
//    let down_wall = down_valid && display_state.map[(x, y + 1)].tile_type == TileType::Wall;
//    let down_left_wall = down_left_valid && display_state.map[(x - 1, y + 1)].tile_type == TileType::Wall;
//
//    /* render full tile wall shadows */
//    if tile.tile_type == TileType::Wall {
//        if left_valid && !left_wall {
//            // left
//            let shadow_pos = Pos::new(x - 1, y);
//            let shadow_left_upper = Sprite::new(SHADOW_FULLTILE_LEFT as u32, shadow_sprite_key);
//            panel.sprite_cmd(shadow_left_upper, shadow_color, shadow_pos);
//        }
//
//        if down_left_valid && !down_left_wall {
//            let shadow_pos = Pos::new(x - 1, y + 1);
//            let shadow_left_lower = Sprite::new(SHADOW_FULLTILE_LEFT_DOWN as u32, shadow_sprite_key);
//            panel.sprite_cmd(shadow_left_lower, shadow_color, shadow_pos);
//        }
//
//        if down_valid && !down_wall {
//            // lower
//            let shadow_lower_right = Sprite::new(SHADOW_FULLTILE_DOWN as u32, shadow_sprite_key);
//            let shadow_pos = Pos::new(x, y + 1);
//            panel.sprite_cmd(shadow_lower_right, shadow_color, shadow_pos);
//        }
//
//        if down_left_valid && !down_left_wall {
//            let shadow_lower_left = Sprite::new(SHADOW_FULLTILE_DOWN_LEFT as u32, shadow_sprite_key);
//            let shadow_pos = Pos::new(x - 1, y + 1);
//            panel.sprite_cmd(shadow_lower_left, shadow_color, shadow_pos);
//        }
//    }
//
//    /* render inter-tile wall shadows */
//    if tile.left_wall == Wall::ShortWall {
//        // left
//        if left_valid {
//            let shadow_pos = Pos::new(x - 1, y);
//            let shadow_left_upper = Sprite::new(SHADOW_INTERTILE_LEFT as u32, shadow_sprite_key);
//            panel.sprite_cmd(shadow_left_upper, shadow_color, shadow_pos);
//        }
//
//        // left down
//        if down_left_valid {
//            let shadow_pos = Pos::new(x - 1, y + 1);
//            let shadow_left_lower = Sprite::new(SHADOW_INTERTILE_LEFT_DOWN as u32, shadow_sprite_key);
//            panel.sprite_cmd(shadow_left_lower, shadow_color, shadow_pos);
//        }
//    }
//
//    if tile.bottom_wall == Wall::ShortWall {
//        // lower
//        if down_valid {
//            let shadow_lower_right = Sprite::new(SHADOW_INTERTILE_DOWN as u32, shadow_sprite_key);
//            let shadow_pos = Pos::new(x, y + 1);
//            panel.sprite_cmd(shadow_lower_right, shadow_color, shadow_pos);
//        }
//
//        // left down
//        if down_left_valid {
//            let shadow_lower_left = Sprite::new(SHADOW_INTERTILE_DOWN_LEFT as u32, shadow_sprite_key);
//            let shadow_pos = Pos::new(x - 1, y + 1);
//            panel.sprite_cmd(shadow_lower_left, shadow_color, shadow_pos);
//        }
//    }
//}
