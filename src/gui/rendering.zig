const std = @import("std");
const print = std.debug.print;
const AutoHashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

const engine = @import("engine");
const UseAction = engine.use.UseAction;
const Game = engine.game.Game;
const Behavior = engine.ai.Behavior;

const core = @import("core");
const entities = core.entities;
const Entities = entities.Entities;
const Stance = entities.Stance;
const Name = entities.Name;
const Config = core.config.Config;
const items = core.items;
const ItemClass = core.items.ItemClass;
const Talent = core.talents.Talent;

const board = @import("board");
const Tile = board.tile.Tile;
const FovResult = board.blocking.FovResult;

const gui = @import("gui.zig");
const DisplayState = gui.DisplayState;
const ConsoleLog = gui.ConsoleLog;

const utils = @import("utils");
const intern = utils.intern;
const Str = intern.Str;
const Intern = intern.Intern;
const Comp = utils.comp.Comp;
const Id = utils.comp.Id;

const math = @import("math");
const Pos = math.pos.Pos;
const Color = math.utils.Color;
const Direction = math.direction.Direction;
const Easing = math.easing.Easing;
const Tween = math.tweening.Tween;
const Rect = math.rect.Rect;

const drawing = @import("drawing");
const DrawCmd = drawing.drawcmd.DrawCmd;
const Panel = drawing.panel.Panel;
const Sprites = drawing.sprite.Sprites;
const Sprite = drawing.sprite.Sprite;
const SpriteSheet = drawing.sprite.SpriteSheet;
const SpriteAnimation = drawing.sprite.SpriteAnimation;
const Animation = drawing.animation.Animation;

pub const Painter = struct {
    sprites: *const AutoHashMap(Str, SpriteSheet),
    drawcmds: *ArrayList(DrawCmd),
    strings: *const Intern,
    state: *DisplayState,
    dt: u64,
    area: Rect,

    pub fn sprite(painter: *Painter, name: []const u8) Sprite {
        const key = painter.strings.toKey(name);
        return painter.sprites.get(key).?.sprite();
    }

    pub fn retarget(painter: *Painter, drawcmds: *ArrayList(DrawCmd), area: Rect) void {
        painter.drawcmds = drawcmds;
        painter.area = area;
    }
};

pub fn renderLevel(game: *Game, painter: *Painter) !void {
    try renderMapLow(game, painter);
    try renderMapMiddle(game, painter);
    try renderEntities(game, painter);
    try renderMapHigh(game, painter);
    try renderOverlays(game, painter);
}

fn renderMapLow(game: *Game, painter: *Painter) !void {
    const open_tile_sprite = painter.sprite("open_tile");
    const grass_tile_sprite = painter.sprite("grass");
    const rubble_tile_sprite = painter.sprite("rubble");

    var y: i32 = 0;
    while (y < game.level.map.height) : (y += 1) {
        var x: i32 = 0;
        while (x < game.level.map.width) : (x += 1) {
            const pos = Pos.init(x, y);
            const tile = game.level.map.get(pos);

            try painter.drawcmds.append(DrawCmd.sprite(open_tile_sprite, Color.white(), pos));
            if (tile.center.material == Tile.Material.rubble) {
                try painter.drawcmds.append(DrawCmd.sprite(rubble_tile_sprite, Color.white(), pos));
            } else if (tile.center.material == Tile.Material.grass) {
                try painter.drawcmds.append(DrawCmd.sprite(grass_tile_sprite, Color.white(), pos));
            }
        }
    }
}

fn renderEntities(game: *Game, painter: *Painter) !void {
    // Render items first, then all other entities so items will appear to be at the entities feet.

    for (painter.state.animation.ids.items) |id| {
        if (game.level.entities.typ.get(id) == .item and game.level.entities.status.get(id).active) {
            if (painter.state.animation.get(id).draw()) |drawcmd| {
                try painter.drawcmds.append(drawcmd);
            }
        }
    }

    for (painter.state.animation.ids.items) |id| {
        if (game.level.entities.typ.get(id) != .item and game.level.entities.status.get(id).active) {
            if (painter.state.animation.get(id).draw()) |drawcmd| {
                try painter.drawcmds.append(drawcmd);
            }
        }
    }
}

fn renderMapMiddle(game: *Game, painter: *Painter) !void {
    const stone_wall_sprite = painter.sprite("horizontal_wall");
    const grass_wall_sprite = painter.sprite("tall_grass");

    var y: i32 = 0;
    while (y < game.level.map.height) : (y += 1) {
        var x: i32 = 0;
        while (x < game.level.map.width) : (x += 1) {
            const pos = Pos.init(x, y);
            const tile = game.level.map.get(pos);

            try renderWallShadow(pos, game, painter);

            if (tile.center.height == .tall) {
                var wall_sprite = stone_wall_sprite;
                if (tile.center.material == .grass) {
                    wall_sprite = grass_wall_sprite;
                }
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

            // Apply a FoW darkening to cells.
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
    try renderOverlayUseMode(game, painter);
    try renderOverlayEffects(game, painter);
    try renderOverlayEntityFov(game, painter);
    try renderOverlayAlertness(game, painter);
    try renderOverlayParticles(game, painter);
}

fn renderOverlayEffects(game: *Game, painter: *Painter) !void {
    for (painter.state.effects.items) |animation| {
        if (animation.draw()) |drawcmd| {
            const is_in_fov = try game.level.posInFov(Entities.player_id, drawcmd.pos());
            if (is_in_fov == .inside) {
                try painter.drawcmds.append(drawcmd);
            }
        }
    }
}

fn renderOverlayCursor(game: *Game, painter: *Painter) !void {
    if (painter.state.cursor_animation) |*anim| {
        if (game.settings.mode != .cursor and anim.doneTweening()) {
            painter.state.cursor_animation = null;
        } else {
            if (anim.draw()) |drawcmd| {
                try painter.drawcmds.append(drawcmd);
            }
        }
        _ = anim.step(painter.dt);
    }
}

fn renderOverlayEntityFov(game: *Game, painter: *Painter) !void {
    const highlight_color = Color.init(0xcd, 0xb4, 0x96, 255);

    if (game.settings.mode == .cursor) {
        const cursor_pos = game.settings.mode.cursor.pos;
        if (game.level.firstEntityTypeAtPos(cursor_pos, .enemy)) |id| {
            const entity_in_player_fov = try game.level.entityInFov(Entities.player_id, id);
            if (entity_in_player_fov == .inside) {
                const facing = game.level.entities.facing.get(id);
                const entity_pos = game.level.entities.pos.get(id);
                try renderArrow(painter, facing, entity_pos, highlight_color);
                var y: i32 = 0;
                while (y < game.level.map.height) : (y += 1) {
                    var x: i32 = 0;
                    while (x < game.level.map.width) : (x += 1) {
                        const pos = Pos.init(x, y);
                        const is_in_fov = try game.level.isInFov(id, pos, .high);
                        if (is_in_fov == .inside) {
                            try renderOutline(painter, pos, highlight_color);

                            if (math.visibleInDirection(entity_pos, pos, facing)) {
                                try renderOutline(painter, pos, game.config.color_red);
                            }
                        }
                    }
                }
            }
        }
    }
}

fn renderOverlayUseMode(game: *Game, painter: *Painter) !void {
    var attack_highlight_color = game.config.color_red;
    attack_highlight_color.a = game.config.highlight_alpha_attack;

    if (game.settings.mode == .use) {
        if (game.settings.mode.use.use_result) |use_result| {
            if (game.settings.mode.use.dir) |dir| {
                const arrow_pos = dir.offsetPos(game.level.entities.pos.get(Entities.player_id), 1);
                const arrow_color = Color.white();
                try renderArrow(painter, dir, arrow_pos, arrow_color);
            } else {
                for (Direction.directions()) |dir| {
                    if (use_result.use_dir[@enumToInt(dir)]) |use_dir| {
                        for (use_dir.hit_positions.constSlice()) |pos| {
                            try painter.drawcmds.append(DrawCmd.highlightTile(pos, attack_highlight_color));
                        }
                        const arrow_pos = dir.offsetPos(game.level.entities.pos.get(Entities.player_id), 1);
                        const arrow_color = Color.white();
                        try renderArrow(painter, dir, arrow_pos, arrow_color);
                    }
                }
            }
        }
    }

    // NOTE(implement)
    // render player ghost
    //if (display_state.player_ghost) |player_ghost_pos| {
    //    render_entity_ghost(panel, player_id, player_ghost_pos, &config, display_state, sprites);
    //}
}

fn renderOverlayAlertness(game: *Game, painter: *Painter) !void {
    const scale = 1.0;
    const alertness_color = game.config.color_pink;

    for (game.level.entities.behavior.ids.items) |id| {
        const pos = game.level.entities.pos.get(id);

        const in_fov = try game.level.entityInFov(Entities.player_id, id);
        if (in_fov != .inside) {
            continue;
        }

        switch (game.level.entities.behavior.get(id)) {
            .idle => {},

            .alert => {
                const sprite = painter.sprite("exclamation_mark");
                try painter.drawcmds.append(DrawCmd.spriteScaled(sprite, scale, .upRight, alertness_color, pos));
            },

            .investigating => {
                const sprite = painter.sprite("question_mark");
                try painter.drawcmds.append(DrawCmd.spriteScaled(sprite, scale, .upRight, alertness_color, pos));
            },

            .attacking => {
                const sprite = painter.sprite("stunned_mark");
                try painter.drawcmds.append(DrawCmd.spriteScaled(sprite, scale, .upRight, alertness_color, pos));
            },

            .armed => {
                const sprite = painter.sprite("stunned_mark");
                try painter.drawcmds.append(DrawCmd.spriteScaled(sprite, scale, .upRight, alertness_color, pos));
            },
        }
    }
}

fn renderOverlayParticles(game: *Game, painter: *Painter) !void {
    for (painter.state.particles.items) |particle| {
        const percent = (@intToFloat(f32, particle.time) / @intToFloat(f32, particle.duration));
        const x = particle.start_x + ((particle.end_x - particle.start_x) * percent);
        var color = Color.white();
        color.a = @floatToInt(u8, 255.0 * (1.0 - percent));
        const drawcmd = DrawCmd.spriteFloat(particle.sprite, color, x, particle.y, 0.1, 0.1);
        const is_in_fov = try game.level.posInFov(Entities.player_id, drawcmd.pos());
        if (is_in_fov == .inside) {
            try painter.drawcmds.append(drawcmd);
        }
    }
}

pub fn renderPips(game: *Game, painter: *Painter) !void {
    const hp = game.level.entities.hp.get(Entities.player_id);
    const health_color = Color.init(0x96, 0x54, 0x56, 255);

    const hp_bar_width = @intToFloat(f32, painter.area.width) / @intToFloat(f32, game.config.player_health_max);

    const current_hp = std.math.max(hp, 0);

    var hp_index: usize = 0;
    while (hp_index < current_hp) : (hp_index += 1) {
        const offset = 0.15;
        const bar_x = @intToFloat(f32, hp_index) * hp_bar_width + offset;
        const bar_y = offset;
        const filled = hp_index <= current_hp;
        try painter.drawcmds.append(DrawCmd.rectFloat(bar_x, bar_y, hp_bar_width - offset * 2.0, 1.0 - offset * 2.0, filled, health_color));
    }

    const energy = game.level.entities.energy.get(Entities.player_id);
    const energy_color = Color.init(176, 132, 87, 255);

    const energy_bar_width = @intToFloat(f32, painter.area.width) / @intToFloat(f32, game.config.player_energy_max);

    var energy_index: usize = 0;
    while (energy_index < energy) : (energy_index += 1) {
        const x_offset = 0.3;
        const y_offset = 0.2;
        const bar_x = @intToFloat(f32, energy_index) * energy_bar_width + x_offset;
        const bar_y = 1.0 + y_offset;
        const filled = energy_index <= energy;
        try painter.drawcmds.append(DrawCmd.rectFloat(bar_x, bar_y, energy_bar_width - x_offset * 2.0, 1.0 - y_offset * 2.0, filled, energy_color));
    }
}

pub fn renderPlayer(game: *Game, painter: *Painter, allocator: Allocator) !void {
    var list: ArrayList([]u8) = ArrayList([]u8).init(allocator);

    const x_offset: usize = 1;

    const stance = game.level.entities.stance.get(Entities.player_id);
    try list.append(try allocator.dupe(u8, @tagName(stance)));

    const move_mode = game.level.entities.move_mode.get(Entities.player_id);
    const next_move_msg = try std.fmt.allocPrint(allocator, "next move {s}", .{@tagName(move_mode)});
    try list.append(next_move_msg);

    try list.append(try std.fmt.allocPrint(allocator, "turn {}", .{painter.state.turn_count}));

    const text_pos = Pos.init(x_offset, 1);

    const ui_color = Color.init(0xcd, 0xb4, 0x96, 255);
    try renderTextList(painter, list, ui_color, text_pos, 1.0);
}

fn renderTextList(painter: *Painter, text_list: ArrayList([]u8), color: Color, cell: Pos, scale: f32) !void {
    for (text_list.items) |str, index| {
        const text_cell = Pos.init(cell.x, cell.y + @intCast(i32, index));
        try painter.drawcmds.append(DrawCmd.text(str, text_cell, color, scale));
    }
}

pub const ColoredText = struct {
    text: []u8,
    color: Color,
};

fn renderColoredTextList(painter: *Painter, text_list: ArrayList(ColoredText), cell: Pos, scale: f32) !void {
    for (text_list.items) |colored_text, index| {
        const text_cell = Pos.init(cell.x, cell.y + @intCast(i32, index));
        try painter.drawcmds.append(DrawCmd.text(colored_text.text, text_cell, colored_text.color, scale));
    }
}

pub fn renderInventory(game: *Game, painter: *Painter, allocator: Allocator) !void {
    var x_offset: f32 = game.config.x_offset_buttons;
    var y_offset: f32 = game.config.y_offset_buttons;

    // Talents
    try renderInventoryTalent('Q', 0, x_offset, y_offset, game, painter, allocator);

    x_offset += game.config.x_spacing_buttons;
    try renderInventoryTalent('W', 1, x_offset, y_offset, game, painter, allocator);

    x_offset += game.config.x_spacing_buttons;
    try renderInventoryTalent('E', 2, x_offset, y_offset, game, painter, allocator);

    x_offset += game.config.x_spacing_buttons;
    try renderInventoryTalent('R', 3, x_offset, y_offset, game, painter, allocator);

    // Skills
    y_offset += game.config.y_spacing_buttons;
    x_offset = game.config.x_offset_buttons;
    try renderInventorySkill('A', 0, x_offset, y_offset, game, painter, allocator);

    x_offset += game.config.x_spacing_buttons;
    try renderInventorySkill('S', 1, x_offset, y_offset, game, painter, allocator);

    x_offset += game.config.x_spacing_buttons;
    try renderInventorySkill('D', 2, x_offset, y_offset, game, painter, allocator);

    x_offset += game.config.x_spacing_buttons;
    try renderInventorySkill('F', 3, x_offset, y_offset, game, painter, allocator);

    // Items
    y_offset += game.config.y_spacing_buttons;
    x_offset = game.config.x_offset_buttons;
    try renderInventoryItem('Z', .weapon, x_offset, y_offset, game, painter, allocator);

    x_offset += game.config.x_spacing_buttons;
    try renderInventoryItem('X', .throwing, x_offset, y_offset, game, painter, allocator);

    x_offset += game.config.x_spacing_buttons;
    try renderInventoryItem('C', .artifact0, x_offset, y_offset, game, painter, allocator);

    // NOTE(implement) add in
    //x_offset += game.config.x_spacing_buttons;
    //try renderInventoryItem('V', InventorySlot.artifact1, x_offset, y_offset, game, painter, allocator);

    //const text_color: Color = undefined;
    //const button_name: []u8 = undefined;
    //if (shouldHighlightItem(&display_state, UseAction.item(ItemClass.misc))) {
    //    button_name = "C_Button_Highlight";
    //    text_color = Color = Color.init(0, 0, 0, 255);
    //} else {
    //    button_name = "C_Button_Base";
    //    text_color = Color.init(0xcd, 0xb4, 0x96, 255);
    //}
    //try renderButton(button_name, x_offset, y_offset, painter, &game.config);

    //const text_x_offset = x_offset + game.config.ui_inv_name_x_offset;
    //const text_y_offset = y_offset + game.config.ui_inv_name_y_offset;
    //var num_stones: usize = 0;
    //for (item, _item_class) in display_state.inventory.iter() {
    //    if (item == Item.stone) {
    //        num_stones += 1;
    //    }
    //}
    //if (num_stones > 0) {
    //    const item_text = try std.fmt.allocPrint("Stone x{}", .{num_stones});
    //    try painter.drawcmds.append(DrawCmd.textFloat(item_text, text_color, text_x_offset, text_y_offset, game.config.ui_inv_name_scale));
    //}
}

fn renderInventoryTalent(chr: u8, index: usize, x_offset: f32, y_offset: f32, game: *const Game, painter: *Painter, allocator: Allocator) !void {
    _ = index;
    _ = allocator;
    //const ui_color = Color.init(0xcd, 0xb4, 0x96, 255);
    //const highlight_ui_color = Color.init(0, 0, 0, 255);

    //var text_color = ui_color;

    var button_name_base = [_]u8{ '0', '_', 'B', 'u', 't', 't', 'o', 'n', '_', 'B', 'a', 's', 'e' };
    //var button_name_highlight: [_]u8 = [_]u8{ "'0', '_', 'B', 'u', 't', 't', 'o', 'n', '_', 'H', 'i', 'g', 'h', 'l', 'i', 'g', 'h', 't' };
    var button_name: []u8 = button_name_base[0..];

    // NOTE(implement) add when talents are implemented.
    //if (game.settings.state == .use) {
    //    if (UseAction.talent(talent) == display_state.use_action) {
    //        if display_state.talents.iter().position(|tal| *tal == talent) == index {
    //            button_name = button_name_highlight;
    //            text_color = highlight_ui_color;
    //        }
    //    }
    //} else if (game.settings.cursor_pos.is_some()) {
    //    if (UseAction.talent(talent) == display_state.cursor_action) {
    //        if display_state.talents.iter().position(|tal| *tal == talent) == index {
    //            button_name = button_name_highlight;
    //            text_color = highlight_ui_color;
    //        }
    //    }
    //}
    button_name[0] = chr;

    try renderButton(button_name, x_offset, y_offset, painter, &game.config);
    // NOTE(implement) add when talents are implemented.
    //if (painter.state.talents.get(index)) |talent| {
    //    try renderTalent(*talent, x_offset, y_offset, text_color, game, painter);
    //}
}

fn renderTalent(talent: Talent, x_offset: f32, y_offset: f32, color: Color, painter: *Painter, config: *const Config) !void {
    const first_word: []u8 = undefined;
    var second_word = "";
    switch (talent) {
        Talent.invigorate => {
            first_word = "invigorate";
        },

        Talent.strongAttack => {
            first_word = "strong";
            second_word = "attack";
        },

        Talent.sprint => {
            first_word = "sprint";
        },

        Talent.push => {
            first_word = "push";
        },

        Talent.energyShield => {
            first_word = "energy";
            second_word = "shield";
        },
    }

    renderName(first_word, second_word, x_offset, y_offset, color, painter, config);
}

fn renderName(first_word: []u8, second_word: []u8, x_offset: f32, y_offset: f32, color: Color, painter: *Painter, config: *const Config) !void {
    if (second_word.len() > 0) {
        const first_x_offset = x_offset + config.ui_inv_name_0_x_offset;
        const first_y_offset = y_offset + config.ui_inv_name_0_y_offset;
        try painter.drawcmds.append(DrawCmd.textFloat(first_word, color, first_x_offset, first_y_offset, config.ui_inv_name_0_scale));

        const second_x_offset = x_offset + config.ui_inv_name_1_x_offset;
        const second_y_offset = y_offset + config.ui_inv_name_1_y_offset;
        try painter.drawcmds.append(DrawCmd.textFloat(second_word, color, second_x_offset, second_y_offset, config.ui_inv_name_1_scale));
    } else {
        const text_x_offset = x_offset + config.ui_inv_name_x_offset;
        const text_y_offset = y_offset + config.ui_inv_name_y_offset;

        const scale: f32 = undefined;
        if (first_word.len() >= 10) {
            scale = config.ui_long_name_scale;
        } else {
            scale = config.ui_inv_name_scale;
        }
        try painter.drawcmds.append(DrawCmd.textFloat(first_word, color, text_x_offset, text_y_offset, scale));
    }
}

pub fn renderInventorySkill(chr: u8, index: usize, x_offset: f32, y_offset: f32, game: *const Game, painter: *Painter, allocator: Allocator) !void {
    const ui_color = Color.init(0xcd, 0xb4, 0x96, 255);
    const highlight_ui_color = Color.init(0, 0, 0, 255);

    var text_color = ui_color;

    var button_name_base = "0_Button_Base";
    var button_name_highlight = "0_Button_Highlight";
    var button_name: [32]u8 = [1]u8{0} ** 32;
    std.mem.copy(u8, &button_name, button_name_base);
    var button_name_len = button_name_base.len;

    if (game.settings.mode == .use) {
        const enough_skills = game.level.entities.skills.get(Entities.player_id).items.len > index;
        if (enough_skills and game.settings.mode == .cursor) {
            if (game.settings.mode.cursor.use_action) |use_action| {
                if (use_action == .skill) {
                    const use_skill = game.settings.mode.use.use_action.skill.skill;
                    if (game.level.entities.skills.get(Entities.player_id).items[index] == use_skill) {
                        std.mem.copy(u8, &button_name, button_name_highlight);
                        button_name_len = button_name_highlight.len;
                        text_color = highlight_ui_color;
                    }
                }
            }
        }
    } else if (game.settings.mode == .cursor) {
        const enough_skills = game.level.entities.skills.get(Entities.player_id).items.len > index;
        if (enough_skills) {
            if (game.settings.mode.cursor.use_action) |use_action| {
                if (use_action == .skill) {
                    const skill = use_action.skill.skill;
                    if (game.level.entities.skills.get(Entities.player_id).items[index] == skill) {
                        std.mem.copy(u8, &button_name, button_name_highlight);
                        button_name_len = button_name_highlight.len;
                        text_color = highlight_ui_color;
                    }
                }
            }
        }
    }
    button_name[0] = chr;

    try renderButton(button_name[0..button_name_len], x_offset, y_offset, painter, &game.config);
    if (game.level.entities.skills.get(Entities.player_id).items.len > index) {
        const skill = game.level.entities.skills.get(Entities.player_id).items[index];
        var skill_text = try utils.displayName(@tagName(skill), allocator);
        try renderInventoryButtonText(skill_text.first, skill_text.second, x_offset, y_offset, text_color, game, painter);
    }
}

fn shouldHighlightItem(game: *const Game, use_action: UseAction) bool {
    const use_mode_action = game.settings.mode == .use and std.meta.eql(game.settings.mode.use.use_action, use_action);
    const cursor_mode_action = game.settings.mode == .cursor and std.meta.eql(game.settings.mode.cursor.use_action, use_action);
    return use_mode_action or cursor_mode_action;
}

fn renderInventoryItem(chr: u8, slot: items.InventorySlot, x_offset: f32, y_offset: f32, game: *const Game, painter: *Painter, allocator: Allocator) !void {
    const ui_color = Color.init(0xcd, 0xb4, 0x96, 255);
    const highlight_ui_color = Color.init(0, 0, 0, 255);

    var text_color: Color = ui_color;

    var button_name_base = [_]u8{ '0', '_', 'B', 'u', 't', 't', 'o', 'n', '_', 'B', 'a', 's', 'e' };
    var button_name_highlight = [_]u8{ '0', '_', 'B', 'u', 't', 't', 'o', 'n', '_', 'H', 'i', 'g', 'h', 'l', 'i', 'g', 'h', 't' };
    var button_name: []u8 = button_name_base[0..];
    var button_len = button_name_base.len;

    if (game.level.entities.inventory.get(Entities.player_id).accessSlot(slot) != null) {
        if (shouldHighlightItem(game, UseAction{ .item = slot })) {
            button_name = button_name_highlight[0..];
            button_len = button_name_highlight.len;
            text_color = highlight_ui_color;
        }
    }
    button_name[0] = chr;
    try renderButton(button_name[0..button_len], x_offset, y_offset, painter, &game.config);

    if (game.level.entities.inventory.get(Entities.player_id).accessSlot(slot)) |item_id| {
        const item = game.level.entities.item.get(item_id);
        var item_text = try utils.displayName(@tagName(item), allocator);
        try renderInventoryButtonText(item_text.first, item_text.second, x_offset, y_offset, text_color, game, painter);
    }
}

fn renderInventoryButtonText(first: []const u8, second: []const u8, x_offset: f32, y_offset: f32, color: Color, game: *const Game, painter: *Painter) !void {
    const text_x_offset = x_offset + game.config.ui_inv_name_x_offset;
    const text_y_offset = y_offset + game.config.ui_inv_name_y_offset;

    if (second.len > 0) {
        const name_x_offset = game.config.ui_inv_name_second_x_offset;
        const name_y_offset = game.config.ui_inv_name_second_y_offset;
        try painter.drawcmds.append(DrawCmd.textFloat(first, text_x_offset + name_x_offset, text_y_offset - name_y_offset, .center, color, game.config.ui_inv_name_scale));
        try painter.drawcmds.append(DrawCmd.textFloat(second, text_x_offset + name_x_offset, text_y_offset + name_y_offset, .center, color, game.config.ui_inv_name_scale));
    } else {
        try painter.drawcmds.append(DrawCmd.textFloat(first, text_x_offset, text_y_offset, .center, color, game.config.ui_inv_name_scale));
    }
}

fn renderButton(name: []u8, x_offset: f32, y_offset: f32, painter: *Painter, config: *const Config) !void {
    const ui_color = Color.init(0xcd, 0xb4, 0x96, 255);

    const button = painter.sprite(name);
    try painter.drawcmds.append(DrawCmd.spriteFloat(button, ui_color, x_offset, y_offset, config.x_scale_buttons, config.y_scale_buttons));
}

pub fn renderInfo(game: *Game, painter: *Painter) !void {
    const text_color = Color.init(0xcd, 0xb4, 0x96, 255);

    if (game.settings.mode == .cursor) {
        const info_pos = game.settings.mode.cursor.pos;

        const x_offset: i32 = 1;

        var object_ids = ArrayList(Id).init(game.frame_allocator);
        try game.level.entitiesAtPos(info_pos, &object_ids);

        var y_pos: i32 = 1;

        var text_list = ArrayList([]u8).init(game.frame_allocator);

        try text_list.append(try std.fmt.allocPrint(game.frame_allocator, "({:>2},{:>2})", .{ info_pos.x, info_pos.y }));

        var text_pos = Pos.init(x_offset, y_pos);

        try renderTextList(painter, text_list, text_color, text_pos, 1.0);

        text_list.clearRetainingCapacity();

        y_pos += 1;

        var drawn_info = false;

        const player_id = Entities.player_id;
        for (object_ids.items) |obj_id| {
            const entity_in_fov = try game.level.entityInFov(player_id, obj_id) == FovResult.inside;

            // Only display things in the player's FOV.
            if (entity_in_fov) {
                drawn_info = true;

                try text_list.append(try std.fmt.allocPrint(game.frame_allocator, "* {s}", .{@tagName(game.level.entities.name.get(obj_id))}));
                if (game.level.entities.hp.getOrNull(obj_id)) |hp| {
                    try text_list.append(try std.fmt.allocPrint(game.frame_allocator, " hp {}", .{hp}));
                } else {
                    try text_list.append("");
                }

                // Show facing direction for player and monsters.
                if (game.level.entities.typ.get(obj_id) == .player or game.level.entities.typ.get(obj_id) == .enemy) {
                    if (game.level.entities.facing.getOrNull(obj_id)) |direction| {
                        try text_list.append(try std.fmt.allocPrint(game.frame_allocator, " facing {s}", .{@tagName(direction)}));
                    }
                }

                if (game.level.entities.hp.getOrNull(obj_id)) |entity_hp| {
                    if (entity_hp == 0) {
                        try text_list.append(try game.frame_allocator.dupe(u8, "  dead"));
                    } else if (game.level.entities.behavior.getOrNull(obj_id)) |behave| {
                        try text_list.append(try std.fmt.allocPrint(game.frame_allocator, " currently {s}", .{@tagName(behave)}));
                    }
                }
            }
        }

        // NOTE(implement) impressions imply golems, which are not yet in the game
        // If there was nothing else to draw, check for an impression.
        //if (!drawn_info) {
        //    for (game.level.impressions) |impr| {
        //        if (impr.pos == info_pos) {
        //            try text_list.append("* Golem".to_string());
        //            break;
        //        }
        //    }
        //}

        text_pos = Pos.init(x_offset, y_pos);

        // If the tile is visible, report additional information about it.
        if (try game.level.posInsideFov(player_id, info_pos)) {
            const info_tile = game.level.map.get(info_pos);

            if (info_tile.impassable) {
                try text_list.append(try game.frame_allocator.dupe(u8, "Tile is water"));
            } else {
                try text_list.append(try std.fmt.allocPrint(game.frame_allocator, "Tile is {s} {s}", .{ @tagName(game.level.map.get(info_pos).center.height), @tagName(game.level.map.get(info_pos).center.material) }));
            }

            if (info_tile.down.height != .empty) {
                try text_list.append(try game.frame_allocator.dupe(u8, "Lower wall"));
            }

            if (game.level.map.isWithinBounds(info_pos.moveX(1)) and
                game.level.map.get(info_pos.moveX(1)).left.height != .empty)
            {
                try text_list.append(try game.frame_allocator.dupe(u8, "Right wall"));
            }

            if (game.level.map.isWithinBounds(info_pos.moveY(-1)) and
                game.level.map.get(info_pos.moveY(-1)).down.height != .empty)
            {
                try text_list.append(try game.frame_allocator.dupe(u8, "Top wall"));
            }

            if (info_tile.left.height != .empty) {
                try text_list.append(try game.frame_allocator.dupe(u8, "Left wall"));
            }

            if (board.blocking.BlockedType.move.tileBlocks(info_tile) != .empty)
                try text_list.append(try std.fmt.allocPrint(game.frame_allocator, "blocked", .{}));
        }

        try renderTextList(painter, text_list, text_color, text_pos, 1.0);
    } else {
        // Otherwise show console log messages.
        var text_list = ArrayList(ColoredText).init(game.frame_allocator);
        var offset: usize = 0;
        while (offset < ConsoleLog.num_msgs) : (offset += 1) {
            const index = (offset + painter.state.console_log.index) % ConsoleLog.num_msgs;

            if (painter.state.console_log.slices[index].len == 0) {
                continue;
            }

            var color: Color = text_color;
            if ((painter.state.console_log.turns[index] + 1) < painter.state.turn_count) {
                color.a = 200;
            }

            try text_list.append(ColoredText{ .text = painter.state.console_log.slices[index], .color = color });
        }
        const text_pos = Pos.init(1, 1);
        try renderColoredTextList(painter, text_list, text_pos, 1.0);
    }
}

fn renderArrow(painter: *Painter, dir: Direction, pos: Pos, color: Color) !void {
    var rotation: f64 = undefined;
    var arrow_name: []const u8 = undefined;

    switch (dir) {
        .up => {
            rotation = -90.0;
            arrow_name = "arrow_horiz"[0..];
        },

        .down => {
            rotation = 90.0;
            arrow_name = "arrow_horiz"[0..];
        },

        .right => {
            rotation = 0.0;
            arrow_name = "arrow_horiz"[0..];
        },

        .left => {
            rotation = 180.0;
            arrow_name = "arrow_horiz"[0..];
        },

        .downLeft => {
            rotation = -180.0;
            arrow_name = "arrow_diag"[0..];
        },

        .downRight => {
            rotation = 90.0;
            arrow_name = "arrow_diag"[0..];
        },

        .upLeft => {
            rotation = -90.0;
            arrow_name = "arrow_diag"[0..];
        },

        .upRight => {
            rotation = 0.0;
            arrow_name = "arrow_diag"[0..];
        },
    }

    var arrow_sprite = painter.sprite(arrow_name);
    arrow_sprite.rotation = rotation;
    try painter.drawcmds.append(DrawCmd.sprite(arrow_sprite, color, pos));
}

fn renderOutline(painter: *Painter, pos: Pos, color: Color) !void {
    try painter.drawcmds.append(DrawCmd.outlineTile(pos, color));
}

pub fn renderConfirmQuit(painter: *Painter) !void {
    // Render header
    try renderPlacard(painter, "Quit?", 15, 10);

    const y_pos = 2;
    var text_pos = Pos.init(1, y_pos);

    const ui_color = Color.init(0xcd, 0xb4, 0x96, 255);

    try painter.drawcmds.append(DrawCmd.text("q: quit game", text_pos, ui_color, 1.0));
    text_pos.y += 1;

    try painter.drawcmds.append(DrawCmd.text("", text_pos, ui_color, 1.0));
    text_pos.y += 1;

    try painter.drawcmds.append(DrawCmd.text("esc: continue", text_pos, ui_color, 1.0));
    text_pos.y += 1;

    try painter.drawcmds.append(DrawCmd.text("", text_pos, ui_color, 1.0));
    text_pos.y += 1;

    try painter.drawcmds.append(DrawCmd.text("r: restart", text_pos, ui_color, 1.0));
    text_pos.y += 1;

    try painter.drawcmds.append(DrawCmd.text("", text_pos, ui_color, 1.0));
    text_pos.y += 1;

    try painter.drawcmds.append(DrawCmd.text("?: help", text_pos, ui_color, 1.0));
}

pub fn renderHelp(painter: *Painter) !void {
    // Render header
    try renderPlacard(painter, "Help", 35, 35);

    const help = @embedFile("help.txt");

    const y_pos = 2;
    var text_pos = Pos.init(1, y_pos);

    const ui_color = Color.init(0xcd, 0xb4, 0x96, 255);

    var start: usize = 0;
    var index: usize = 0;
    while (index < help.len) : (index += 1) {
        if (help[index] == '\n') {
            if (index - start > 1) {
                try painter.drawcmds.append(DrawCmd.text(help[start..index], text_pos, ui_color, 1.0));
            }
            text_pos.y += 1;
            start = index + 1;
        }
    }
}

fn renderPlacard(painter: *Painter, text: []const u8, width: u32, height: u32) !void {
    // Draw header text
    const text_color = Color.init(0, 0, 0, 255);
    const highlight_color = Color.init(0xcd, 0xb4, 0x96, 255);

    try painter.drawcmds.append(DrawCmd.rect(Pos.init(0, 0), width, height, 0.5, false, highlight_color));
    try painter.drawcmds.append(DrawCmd.textJustify(text, .center, Pos.init(0, 0), text_color, highlight_color, width, 1.0));
}
