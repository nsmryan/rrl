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

const DisplayState = @import("gui.zig").DisplayState;

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

const drawing = @import("drawing");
const DrawCmd = drawing.drawcmd.DrawCmd;
const Area = drawing.area.Area;
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
    area: Area,

    pub fn sprite(painter: *Painter, name: []const u8) Sprite {
        const key = painter.strings.toKey(name);
        return painter.sprites.get(key).?.sprite();
    }

    pub fn retarget(painter: *Painter, drawcmds: *ArrayList(DrawCmd), area: Area) void {
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
    _ = game;
    try painter.drawcmds.append(painter.state.animation.get(Entities.player_id).draw());
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

// NOTE(memory) provide a frame allocator for display stuff.
pub fn renderPlayer(game: *Game, painter: *Painter, allocator: Allocator) !void {
    _ = game;

    var list: ArrayList([]u8) = ArrayList([]u8).init(allocator);

    const x_offset: usize = 1;

    const stance = painter.state.stance.get(Entities.player_id);
    try list.append(try allocator.dupe(u8, @tagName(stance)));

    const move_mode = painter.state.move_mode.get(Entities.player_id);
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

//pub fn renderInventory(game: *Game, painter: *Painter) !void {
//    let ui_color = Color::new(0xcd, 0xb4, 0x96, 255);
//    let highlight_ui_color = Color::new(0, 0, 0, 255);
//
//    let mut x_offset = config.x_offset_buttons;
//    let mut y_offset = config.y_offset_buttons;
//
//    /* Talents */
//    // TODO replace with qwe when available.
//    render_inventory_talent('Q', 0, x_offset, y_offset, panel, display_state, sprites, config);
//
//    x_offset += config.x_spacing_buttons;
//    render_inventory_talent('W', 1, x_offset, y_offset, panel, display_state, sprites, config);
//
//    x_offset += config.x_spacing_buttons;
//    render_inventory_talent('E', 2, x_offset, y_offset, panel, display_state, sprites, config);
//
//    x_offset += config.x_spacing_buttons;
//    render_inventory_talent('R', 3, x_offset, y_offset, panel, display_state, sprites, config);
//
//    /* Skills */
//    y_offset += config.y_spacing_buttons;
//    x_offset = config.x_offset_buttons;
//    render_inventory_skill('A', 0, x_offset, y_offset, panel, display_state, sprites, config);
//
//    x_offset += config.x_spacing_buttons;
//    render_inventory_skill('S', 1, x_offset, y_offset, panel, display_state, sprites, config);
//
//    x_offset += config.x_spacing_buttons;
//    render_inventory_skill('D', 2, x_offset, y_offset, panel, display_state, sprites, config);
//
//    x_offset += config.x_spacing_buttons;
//    render_inventory_skill('F', 3, x_offset, y_offset, panel, display_state, sprites, config);
//
//    /* Items */
//    y_offset += config.y_spacing_buttons;
//    x_offset = config.x_offset_buttons;
//    render_inventory_item('Z', ItemClass::Primary, x_offset, y_offset, panel, display_state, sprites, config);
//
//    x_offset += config.x_spacing_buttons;
//    render_inventory_item('X', ItemClass::Consumable, x_offset, y_offset, panel, display_state, sprites, config);
//
//    x_offset += config.x_spacing_buttons;
//    let text_color;
//    let button_name;
//    if should_highlight_item(display_state, UseAction::Item(ItemClass::Misc)) {
//        button_name = &"C_Button_Highlight";
//        text_color = highlight_ui_color;
//    } else {
//        button_name = &"C_Button_Base";
//        text_color = ui_color;
//    }
//    render_button(button_name, x_offset, y_offset, panel, sprites, config);
//
//    let text_x_offset = x_offset + config.ui_inv_name_x_offset;
//    let text_y_offset = y_offset + config.ui_inv_name_y_offset;
//    let mut num_stones = 0;
//    for (item, _item_class) in display_state.inventory.iter() {
//        if *item == Item::Stone {
//            num_stones += 1;
//        }
//    }
//    if num_stones > 0 {
//        let item_text = format!("Stone x{}", num_stones);
//        panel.text_float_cmd(&item_text, text_color, text_x_offset, text_y_offset, config.ui_inv_name_scale);
//    }
//
//    // TODO need another item class to use for this location.
//    //x_offset += config.x_spacing_buttons;
//    //render_inventory_item('V', ItemClass::Consumable, x_offset, y_offset, panel, display_state, sprites, config);
//}
//
//pub fn renderInfo(game: *Game, painter: *Painter) !void {
//    let text_color = Color::new(0xcd, 0xb4, 0x96, 255);
//
//    if let Some(info_pos) = display_state.cursor_pos {
//        let x_offset = 1;
//
//        let object_ids = display_state.entities_at_cursor.clone();
//
//        let mut y_pos = 1;
//
//        let mut text_list = Vec::new();
//
//        text_list.push(format!("({:>2},{:>2})", info_pos.x, info_pos.y));
//
//        let text_pos = Pos::new(x_offset, y_pos);
//
//        panel.text_list_cmd(&text_list, text_color, text_pos, 1.0);
//
//        text_list.clear();
//
//        y_pos += 1;
//
//        let mut drawn_info = false;
//
//        // only display first object
//        //if let Some(obj_id) = object_ids.first() {
//        for obj_id in object_ids {
//            let entity_in_fov = display_state.entity_is_in_fov(obj_id) == FovResult::Inside;
//
//            // only display things in the player's FOV
//            if entity_in_fov {
//                drawn_info = true;
//
//                text_list.push(format!("* {:?}", display_state.name[&obj_id]));
//                if let Some(hp) = display_state.hp.get(&obj_id) {
//                    text_list.push(format!(" hp {:?}", hp));
//                } else {
//                    text_list.push("".to_string());
//                }
//
//                // show facing direction for player and monsters
//                if display_state.typ[&obj_id] == EntityType::Player ||
//                   display_state.typ[&obj_id] == EntityType::Enemy {
//                    if let Some(direction) = display_state.direction.get(&obj_id) {
//                        text_list.push(format!(" facing {}", direction));
//                    }
//                }
//
//                if matches!(display_state.hp.get(&obj_id), Some(0)) {
//                    text_list.push(format!("  {}", "dead"));
//                } else if let Some(behave) = display_state.behavior.get(&obj_id) {
//                    text_list.push(format!(" currently {}", behave.description()));
//                }
//            }
//        }
//
//        // if there was nothing else to draw, check for an impression
//        if !drawn_info {
//            for impr in display_state.impressions.iter() {
//                if impr.pos == info_pos {
//                    text_list.push("* Golem".to_string());
//                    break;
//                }
//            }
//        }
//
//        let text_pos = Pos::new(x_offset, y_pos);
//        panel.text_list_cmd(&text_list, text_color, text_pos, 1.0);
//
//        if display_state.fov.get(&info_pos) == Some(&FovResult::Inside) {
//            if display_state.map[info_pos].tile_type == TileType::Water {
//                text_list.push("Tile is water".to_string());
//            } else {
//                text_list.push(format!("Tile is {:?}",  display_state.map[info_pos].surface));
//            }
//
//            if display_state.map[info_pos].bottom_wall != Wall::Empty {
//                text_list.push("Lower wall".to_string());
//            }
//
//            if display_state.map.is_within_bounds(move_x(info_pos, 1)) &&
//               display_state.map[move_x(info_pos, 1)].left_wall != Wall::Empty {
//                text_list.push("Right wall".to_string());
//            }
//
//            if display_state.map.is_within_bounds(move_y(info_pos, -1)) &&
//               display_state.map[move_y(info_pos, -1)].bottom_wall != Wall::Empty {
//                text_list.push("Top wall".to_string());
//            }
//
//            if display_state.map[info_pos].left_wall != Wall::Empty {
//                text_list.push("Left wall".to_string());
//            }
//
//            if display_state.map.tile_is_blocking(info_pos) {
//                text_list.push(format!("blocked"));
//            }
//        }
//
//        panel.text_list_cmd(&text_list, text_color, text_pos, 1.0);
//    } else {
//        // otherwise show console log messages
//        let mut text_list = Vec::new();
//        for index in 0..display_state.msg_lines.len() {
//            let (turn, msg) = display_state.msg_lines[index].clone();
//
//            let color = if (turn + 1) == display_state.turn_count {
//                text_color
//            } else {
//                let mut color = text_color;
//                color.a = 200;
//                color
//            };
//
//            text_list.push((color, msg));
//        }
//        let text_pos = Pos::new(1, 1);
//        panel.colored_text_list_cmd(&text_list, text_pos, 1.0);
//    }
//}
