const std = @import("std");
const print = std.debug.print;
const AutoHashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

const engine = @import("engine");
const Game = engine.game.Game;

const core = @import("core");
const entities = core.entities;
const Entities = entities.Entities;
const Stance = entities.Stance;
const Name = entities.Name;

const board = @import("board");
const Tile = board.tile.Tile;
const FovResult = board.blocking.FovResult;

const utils = @import("utils");
const intern = utils.intern;
const Str = intern.Str;
const Intern = intern.Intern;
const Comp = utils.comp.Comp;

const math = @import("math");
const Pos = math.pos.Pos;
const Color = math.utils.Color;
const Direction = math.direction.Direction;
const Easing = math.easing.Easing;
const Tween = math.tweening.Tween;

const drawcmd = @import("drawcmd");
const DrawCmd = drawcmd.drawcmd.DrawCmd;
const Panel = drawcmd.panel.Panel;
const Sprites = drawcmd.sprite.Sprites;
const Sprite = drawcmd.sprite.Sprite;
const SpriteSheet = drawcmd.sprite.SpriteSheet;
const SpriteAnimation = drawcmd.sprite.SpriteAnimation;
const Animation = drawcmd.animation.Animation;

pub const Painter = struct {
    sprites: *const AutoHashMap(Str, SpriteSheet),
    drawcmds: *ArrayList(DrawCmd),
    strings: *const Intern,
    state: *DisplayState,
    dt: u64,

    pub fn sprite(painter: *Painter, name: []const u8) Sprite {
        const key = painter.strings.toKey(name);
        return painter.sprites.get(key).?.sprite();
    }
};

pub const DisplayState = struct {
    pos: Comp(Pos),
    stance: Comp(Stance),
    name: Comp(Name),
    facing: Comp(Direction),
    animation: Comp(Animation),
    cursor_animation: ?Animation = null,

    pub fn init(allocator: Allocator) DisplayState {
        var state: DisplayState = undefined;
        comptime var names = entities.compNames(DisplayState);
        state.cursor_animation = null;
        inline for (names) |field_name| {
            @field(state, field_name) = @TypeOf(@field(state, field_name)).init(allocator);
        }
        return state;
    }

    pub fn deinit(state: *DisplayState) void {
        comptime var names = entities.compNames(DisplayState);
        inline for (names) |field_name| {
            @field(state, field_name).deinit();
        }
    }
};

pub fn render(game: *Game, painter: *Painter) !void {
    try renderMapLow(game, painter);
    try renderMapMiddle(game, painter);
    try renderEntities(game, painter);
    try renderMapHigh(game, painter);
    try renderOverlays(game, painter);
}

fn renderMapLow(game: *Game, painter: *Painter) !void {
    const open_tile_sprite = painter.sprite("open_tile");

    var y: i32 = 0;
    while (y < game.level.map.height) : (y += 1) {
        var x: i32 = 0;
        while (x < game.level.map.width) : (x += 1) {
            const pos = Pos.init(x, y);
            const tile = game.level.map.get(pos);
            if (tile.center.material == Tile.Material.stone) {
                try painter.drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.white(), pos));
            }
        }
    }
}

fn renderEntities(game: *Game, painter: *Painter) !void {
    const pos = game.level.entities.pos.get(Entities.player_id);
    //const player_sprite = painter.sprite("player_standing_right");
    const player_sprite = painter.state.animation.get(Entities.player_id).sprite_anim.current();
    try painter.drawcmds.append(DrawCmd.sprite(player_sprite, Color.white(), pos));
}

fn renderMapMiddle(game: *Game, painter: *Painter) !void {
    const wall_sprite = painter.sprite("horizontal_wall");

    var y: i32 = 0;
    while (y < game.level.map.height) : (y += 1) {
        var x: i32 = 0;
        while (x < game.level.map.width) : (x += 1) {
            const pos = Pos.init(x, y);
            const tile = game.level.map.get(pos);

            try renderWallShadow(pos, game, painter);

            if (tile.center.height == .tall) {
                try painter.drawcmds.append(DrawCmd.sprite(wall_sprite, Color.white(), pos));
            }
            try renderIntertileWalls(pos, game, painter);
        }
    }
}

fn renderIntertileWalls(pos: Pos, game: *Game, painter: *Painter) !void {
    const tile = game.level.map.get(pos);
    const wall_color = Color.white();

    // Left walls
    if (try intertileSprite(tile.left, "left_intertile_wall", "left_intertile_grass_wall", painter)) |sprite| {
        try painter.drawcmds.append(DrawCmd.sprite(sprite, wall_color, pos));
    }

    // Right walls
    const right_pos = pos.moveX(1);
    if (game.level.map.isWithinBounds(right_pos)) {
        const right_tile = game.level.map.get(right_pos);

        if (try intertileSprite(right_tile.left, "right_intertile_wall", "right_intertile_grass_wall", painter)) |sprite| {
            try painter.drawcmds.append(DrawCmd.sprite(sprite, wall_color, pos));
        }
    }

    // Lower walls not handled as they are drawn above other tiles in render_map_above

    // Upper walls
    const up_pos = pos.moveY(-1);
    if (game.level.map.isWithinBounds(up_pos)) {
        const up_tile = game.level.map.get(up_pos);

        if (try intertileSprite(up_tile.down, "up_intertile_wall", "up_intertile_grass_wall", painter)) |sprite| {
            try painter.drawcmds.append(DrawCmd.sprite(sprite, wall_color, pos));
        }
    }
}

fn intertileSprite(wall: Tile.Wall, stone_name: []const u8, grass_name: []const u8, painter: *Painter) !?Sprite {
    const shortGrassWall = Tile.Wall.init(.short, .grass);
    const shortStoneWall = Tile.Wall.init(.short, .stone);
    const emptyWall = Tile.Wall.init(.empty, .stone);

    if (std.meta.eql(wall, shortGrassWall)) {
        return painter.sprite(grass_name);
    } else if (std.meta.eql(wall, shortStoneWall)) {
        return painter.sprite(stone_name);
    } else if (!std.meta.eql(wall, emptyWall)) {
        // NOTE tall walls and rubble walls are not represented in the tile set.
        unreachable;
    }
    return null;
}

fn renderMapHigh(game: *Game, painter: *Painter) !void {
    const wall_color = Color.white();

    var y: i32 = 0;
    while (y < game.level.map.height) : (y += 1) {
        var x: i32 = 0;
        while (x < game.level.map.width) : (x += 1) {
            const pos = Pos.init(x, y);
            const tile = game.level.map.get(pos);

            // Down walls
            if (try intertileSprite(tile.down, "down_intertile_wall", "down_intertile_grass_wall", painter)) |sprite| {
                try painter.drawcmds.append(DrawCmd.sprite(sprite, wall_color, pos));
            }

            const fov_result = try game.level.posInFov(Entities.player_id, pos);

            // apply a FoW darkening to cells
            if (game.config.fog_of_war and fov_result != FovResult.inside) {
                const is_in_fov_ext = fov_result == FovResult.edge;

                var blackout_color = Color.black();
                if (is_in_fov_ext) {
                    blackout_color.a = game.config.fov_edge_alpha;
                } else if (game.level.posExplored(Entities.player_id, pos)) {
                    blackout_color.a = game.config.explored_alpha;
                }
                try painter.drawcmds.append(DrawCmd.highlightTile(pos, blackout_color));
            }
        }
    }
}

/// Render Wall Shadows (full tile and intertile walls, left and down)
fn renderWallShadow(pos: Pos, game: *Game, painter: *Painter) !void {
    const SHADOW_FULLTILE_LEFT: u32 = 2;
    const SHADOW_FULLTILE_LEFT_DOWN: u32 = 6;
    const SHADOW_FULLTILE_DOWN: u32 = 1;
    const SHADOW_FULLTILE_DOWN_LEFT: u32 = 0;

    const SHADOW_INTERTILE_LEFT: u32 = 3;
    const SHADOW_INTERTILE_LEFT_DOWN: u32 = 7;
    const SHADOW_INTERTILE_DOWN: u32 = 5;
    const SHADOW_INTERTILE_DOWN_LEFT: u32 = 4;

    const tile = game.level.map.get(pos);

    const left_pos = pos.moveX(-1);
    const down_pos = pos.moveY(1);
    const down_left_pos = pos.moveX(-1).moveY(1);

    const left_valid = game.level.map.isWithinBounds(left_pos);
    const down_valid = game.level.map.isWithinBounds(down_pos);
    const down_left_valid = left_valid and down_valid;

    const left_tile_is_wall = left_valid and game.level.map.get(left_pos).center.height == .tall;
    const down_tile_is_wall = down_valid and game.level.map.get(down_pos).center.height == .tall;
    const down_left_tile_is_wall = down_left_valid and game.level.map.get(down_left_pos).center.height == .tall;

    var shadow_sprite = painter.sprite("shadowtiles");

    // Render full tile wall shadows.
    if (tile.center.height == .tall) {
        // left
        if (left_valid and !left_tile_is_wall) {
            shadow_sprite.index = SHADOW_FULLTILE_LEFT;
            try painter.drawcmds.append(DrawCmd.sprite(shadow_sprite, game.config.color_shadow, left_pos));
        }

        // left down
        if (down_left_valid and !down_left_tile_is_wall) {
            shadow_sprite.index = SHADOW_FULLTILE_LEFT_DOWN;
            try painter.drawcmds.append(DrawCmd.sprite(shadow_sprite, game.config.color_shadow, down_left_pos));
        }

        // down
        if (down_valid and !down_tile_is_wall) {
            shadow_sprite.index = SHADOW_FULLTILE_DOWN;
            try painter.drawcmds.append(DrawCmd.sprite(shadow_sprite, game.config.color_shadow, down_pos));
        }

        // Down left
        if (down_left_valid and !down_left_tile_is_wall) {
            shadow_sprite.index = SHADOW_FULLTILE_DOWN_LEFT;
            try painter.drawcmds.append(DrawCmd.sprite(shadow_sprite, game.config.color_shadow, down_left_pos));
        }
    }

    // Render inter-tile wall shadows.
    if (tile.left.height == .short) {
        // left
        if (left_valid) {
            shadow_sprite.index = SHADOW_INTERTILE_LEFT;
            try painter.drawcmds.append(DrawCmd.sprite(shadow_sprite, game.config.color_shadow, left_pos));
        }

        // left down
        if (down_left_valid) {
            shadow_sprite.index = SHADOW_INTERTILE_LEFT_DOWN;
            try painter.drawcmds.append(DrawCmd.sprite(shadow_sprite, game.config.color_shadow, down_left_pos));
        }
    }

    if (tile.down.height == .short) {
        // lower
        if (down_valid) {
            shadow_sprite.index = SHADOW_INTERTILE_DOWN;
            try painter.drawcmds.append(DrawCmd.sprite(shadow_sprite, game.config.color_shadow, down_pos));
        }

        // left down
        if (down_left_valid) {
            shadow_sprite.index = SHADOW_INTERTILE_DOWN_LEFT;
            try painter.drawcmds.append(DrawCmd.sprite(shadow_sprite, game.config.color_shadow, down_left_pos));
        }
    }
}

fn renderOverlays(game: *Game, painter: *Painter) !void {
    try renderOverlayCursor(game, painter);
}

fn renderOverlayCursor(game: *Game, painter: *Painter) !void {
    if (painter.state.cursor_animation) |*anim| {
        if (game.settings.mode != .cursor and anim.doneTweening()) {
            painter.state.cursor_animation = null;
        } else {
            try painter.drawcmds.append(anim.draw());
        }
        _ = anim.step(painter.dt);
    }

    // NOTE(remove) when new animation system is working well enough that the cursor is using it.
    //var color = game.config.color_mint_green;
    //color.a = @floatToInt(u8, painter.state.cursor_tween.value());

    //const cursor_sprite = painter.sprite("targeting");

    //try painter.drawcmds.append(DrawCmd.sprite(cursor_sprite, color, game.settings.mode.cursor.pos));

    // NOTE(implement)
    // render player ghost
    //if (display_state.player_ghost) |player_ghost_pos| {
    //    render_entity_ghost(panel, player_id, player_ghost_pos, &config, display_state, sprites);
    //}
}
