const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;

const utils = @import("utils");
const Str = utils.intern.Str;
const Comp = utils.comp.Comp;
const Id = utils.comp.Id;
const Timer = utils.timer.Timer;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const Tween = math.tweening.Tween;
const Dims = math.utils.Dims;
const Color = math.utils.Color;
const Rect = math.rect.Rect;
const Easing = math.easing.Easing;

const core = @import("core");
const movement = core.movement;
const MoveMode = core.movement.MoveMode;
const Config = core.config.Config;
const entities = core.entities;
const Stance = entities.Stance;
const Name = entities.Name;
const Entities = entities.Entities;
const items = core.items;

const gen = @import("gen");

const board = @import("board");
const Map = board.map.Map;
const FloodFill = board.floodfill.FloodFill;

const engine = @import("engine");
const Game = engine.game.Game;
const Input = engine.input.Input;
const InputEvent = engine.input.InputEvent;
const UseAction = engine.actions.UseAction;
const Settings = engine.actions.Settings;
const GameState = engine.settings.GameState;
const Msg = engine.messaging.Msg;

const drawing = @import("drawing");
const sprite = drawing.sprite;
const Sprite = sprite.Sprite;
const Animation = drawing.animation.Animation;
const SpriteAnimation = sprite.SpriteAnimation;
const Panel = drawing.panel.Panel;
const DrawCmd = drawing.drawcmd.DrawCmd;

const prof = @import("prof");

pub const display = @import("display.zig");
pub const Display = display.Display;
pub const TexturePanel = display.TexturePanel;
pub const keyboard = @import("keyboard.zig");
pub const canvas = @import("canvas.zig");
pub const sdl2 = @import("sdl2.zig");
pub const rendering = @import("rendering.zig");
pub const effects = @import("effects.zig");

pub const Effect = effects.Effect;

const Painter = rendering.Painter;

const Texture = sdl2.SDL_Texture;

pub const MAX_MAP_WIDTH: usize = 80;
pub const MAX_MAP_HEIGHT: usize = 80;

pub const MAP_AREA_CELLS_WIDTH: usize = 44;
pub const MAP_AREA_CELLS_HEIGHT: usize = 20;

pub const UI_CELLS_TOP: u32 = 3;
pub const UI_CELLS_BOTTOM: u32 = 11;

pub const SCREEN_CELLS_WIDTH: usize = MAP_AREA_CELLS_WIDTH;
pub const SCREEN_CELLS_HEIGHT: usize = MAP_AREA_CELLS_HEIGHT + UI_CELLS_TOP + UI_CELLS_BOTTOM;

pub const PIXELS_PER_CELL: usize = 24;
pub const WINDOW_WIDTH: usize = PIXELS_PER_CELL * SCREEN_CELLS_WIDTH;
pub const WINDOW_HEIGHT: usize = PIXELS_PER_CELL * SCREEN_CELLS_HEIGHT;

pub const Gui = struct {
    display: display.Display,
    game: Game,
    state: DisplayState,
    allocator: Allocator,
    profiler: prof.Prof,
    ticks: u64,
    reload_config_timer: Timer,
    panels: Panels,

    pub fn init(seed: u64, use_profiling: bool, allocator: Allocator) !Gui {
        var game = try Game.init(seed, allocator);
        var profiler: prof.Prof = prof.Prof{};
        if (use_profiling and game.config.use_profiling) {
            try profiler.start();
            prof.log("Starting up");
        }

        var disp = try display.Display.init(WINDOW_WIDTH, WINDOW_HEIGHT, allocator);

        var width: c_int = 0;
        var height: c_int = 0;
        sdl2.SDL_GetWindowSize(disp.window, &width, &height);
        const panels = try Panels.init(@intCast(usize, width), @intCast(usize, height), &disp, allocator);

        var state = DisplayState.init(allocator);

        return Gui{
            .display = disp,
            .state = state,
            .game = game,
            .allocator = allocator,
            .profiler = profiler,
            .ticks = 0,
            .reload_config_timer = Timer.init(game.config.reload_config_period),
            .panels = panels,
        };
    }

    pub fn deinit(gui: *Gui) void {
        gui.display.deinit();
        gui.state.deinit();
        gui.game.deinit();
        gui.panels.deinit();
        gui.profiler.end();
    }

    pub fn step(gui: *Gui, ticks: u64) !bool {
        prof.scope("step");
        defer prof.end();

        const delta_ticks = ticks - gui.ticks;

        if (gui.reload_config_timer.step(delta_ticks) > 0) {
            prof.scope("reload config");
            gui.game.reloadConfig();
            prof.end();
        }

        prof.scope("input");
        var event: sdl2.SDL_Event = undefined;
        while (sdl2.SDL_PollEvent(&event) != 0) {
            if (keyboard.translateEvent(event)) |input_event| {
                try gui.inputEvent(input_event, ticks);

                // Process all generated messages for display changes.
                for (gui.game.log.all.items) |msg| {
                    try gui.resolveMessage(msg);
                }
            }
        }
        prof.end();

        gui.ticks = ticks;

        try gui.updateParticles(delta_ticks);

        // Draw whether or not there is an event to update animations, effects, etc.
        prof.scope("draw");
        try gui.draw(delta_ticks);
        defer prof.end();

        return gui.game.settings.state != GameState.exit;
    }

    fn updateParticles(gui: *Gui, dt: u64) !void {
        if (gui.game.config.particles_enabled and
            math.rand.rngTrial(gui.game.rng.random(), gui.game.config.particle_prob))
        {
            try gui.spawnParticle();
        }

        var index: usize = 0;
        while (index < gui.state.particles.items.len) {
            var particle = &gui.state.particles.items[index];
            particle.time += dt;
            if (particle.time > particle.duration) {
                _ = gui.state.particles.swapRemove(index);
            } else {
                index += 1;
            }
        }
    }

    fn spawnParticle(gui: *Gui) !void {
        const rng = gui.game.rng.random();

        const min_duration = gui.game.config.particle_duration_min;
        const max_duration = gui.game.config.particle_duration_max;
        const duration = @floatToInt(u64, math.rand.rngRange(rng, min_duration, max_duration) * 1000);
        const width = @intToFloat(f32, gui.game.level.map.width);
        const height = @intToFloat(f32, gui.game.level.map.height);
        var x = math.rand.rngRange(rng, 0.0, width);
        const y = math.rand.rngRange(rng, 0.0, height);
        const max_length = @intToFloat(f32, gui.game.config.particle_max_length);
        var end_x = x + max_length;
        end_x = @min(@intToFloat(f32, gui.game.level.map.width) - 0.01, end_x);
        x = @min(x, end_x);

        const tile_sprite = try gui.display.getSprite("white_filled");
        try gui.state.particles.append(Particle{
            .start_x = x,
            .y = y,
            .end_x = end_x,
            .duration = duration,
            .time = 0.0,
            .sprite = tile_sprite,
        });
    }

    pub fn inputEvent(gui: *Gui, input_event: InputEvent, ticks: u64) !void {
        try gui.game.step(input_event, ticks);
    }

    pub fn resolveMessages(gui: *Gui) !void {
        while (try gui.game.resolveMessage()) |msg| {
            try gui.resolveMessage(msg);
        }
    }

    pub fn resolveMessage(gui: *Gui, msg: Msg) !void {
        switch (msg) {
            .move => |args| try gui.moveEntity(args.id, args.pos),
            .startLevel => try gui.startLevel(),
            .endTurn => try gui.endTurn(),
            .cursorStart => |args| try gui.cursorStart(args),
            .cursorEnd => gui.cursorEnd(),
            .cursorMove => |args| gui.cursorMove(args),
            .hit => |args| try gui.processHit(args.id, args.start_pos, args.hit_pos, args.weapon_type, args.attack_style),
            .pickedUp => |args| try gui.processPickedUpItem(args.id, args.item_id, args.slot),
            .droppedItem => |args| try gui.processDroppedItem(args.id, args.slot),
            .itemLanded => |args| try gui.processItemLanded(args.id, args.start, args.hit),
            .itemThrow => |args| try gui.processItemThrow(args.id, args.item_id, args.start, args.end, args.hard),
            .sound => |args| try gui.processSound(args.id, args.pos, args.amount),
            .remove => |args| try gui.processRemove(args),

            else => {},
        }

        try gui.state.console_log.queue(&gui.game.level.entities, msg, gui.state.turn_count);
    }

    fn processRemove(gui: *Gui, id: Id) !void {
        gui.state.animation.remove(id);
    }

    fn processSound(gui: *Gui, id: Id, pos: Pos, amount: usize) !void {
        _ = id;
        try gui.soundEffect(0.0, pos, amount);
    }

    fn processItemThrow(gui: *Gui, id: Id, item_id: Id, start: Pos, end: Pos, hard: bool) !void {
        _ = gui;
        _ = id;
        _ = start;
        _ = end;
        _ = hard;
        _ = item_id;
        //const item = gui.game.level.entities.item.get(item_id);
        //_ = gui.state.inventory.drop(item_id, item.class());
    }

    fn processItemLanded(gui: *Gui, id: Id, start: Pos, hit: Pos) !void {
        // Animate the item moving to the hit location.
        const distance = start.distance(hit);
        const throw_duration = distance / gui.game.config.item_throw_speed;
        var sprite_anim = gui.state.animation.get(id).sprite_anim;
        var anim = Animation.init(sprite_anim, Color.white(), hit);
        anim.finishWhenTweensDone();
        anim.moveBetween(start, hit, throw_duration);
        try gui.state.effects.append(Effect.animationEffect(anim));
        gui.state.animation.getPtr(id).delayBy(throw_duration);

        try gui.soundEffect(throw_duration, hit, gui.game.config.sound_radius_stone);
    }

    fn soundEffect(gui: *Gui, delay: f32, pos: Pos, amount: usize) !void {
        // Animate the sound of the item landing after the item lands
        var floodfill = try gui.game.sound(pos, amount);

        const initial_delay = @floatToInt(u64, delay * 1000);
        const fade_half_duration: f32 = 0.25;
        const sound_alpha: f32 = @intToFloat(f32, gui.game.config.sound_alpha) / 255.0;
        const highlight_color = gui.game.config.color_warm_grey;
        const ease_up = gui.game.config.sound_ease_in;
        const ease_down = gui.game.config.sound_ease_out;

        for (floodfill.flood.items) |hit_pos| {
            const first_delay = initial_delay + 100 * @intCast(u64, pos.distanceMaximum(hit_pos.pos));
            const second_delay = first_delay + @floatToInt(u64, fade_half_duration * 1000);

            var outline_tween = Tween.init(0.0, 1.0, fade_half_duration, ease_up);

            var tween = Tween.init(0.0, sound_alpha, fade_half_duration, ease_up);
            try gui.state.effects.append(Effect.highlightEffect(hit_pos.pos, highlight_color, tween, first_delay));
            try gui.state.effects.append(Effect.outlineEffect(hit_pos.pos, highlight_color, outline_tween, first_delay));

            tween = Tween.init(sound_alpha, 0.0, fade_half_duration, ease_down);
            outline_tween = Tween.init(1.0, 0.0, fade_half_duration, ease_up);
            try gui.state.effects.append(Effect.highlightEffect(hit_pos.pos, highlight_color, tween, second_delay));
            try gui.state.effects.append(Effect.outlineEffect(hit_pos.pos, highlight_color, outline_tween, second_delay));
        }
    }

    fn processPickedUpItem(gui: *Gui, id: Id, item_id: Id, slot: items.InventorySlot) !void {
        _ = gui;
        _ = id;
        _ = item_id;
        _ = slot;
    }

    fn processDroppedItem(gui: *Gui, id: Id, slot: items.InventorySlot) !void {
        _ = gui;
        _ = id;
        _ = slot;
    }

    fn processHit(gui: *Gui, id: Id, start_pos: Pos, hit_pos: Pos, weapon_type: items.WeaponType, attack_style: items.AttackStyle) !void {
        _ = id;
        _ = attack_style;

        var name: []const u8 = undefined;
        if (start_pos.eql(hit_pos) or Direction.fromPositions(start_pos, hit_pos).?.diag()) {
            // Diagonal attack.
            switch (weapon_type) {
                .pierce => {
                    name = "player_pierce_diagonal"[0..];
                },

                .slash => {
                    name = "player_slash_diagonal"[0..];
                },

                .blunt => {
                    name = "player_blunt_diagonal"[0..];
                },
            }
        } else {
            // Horizontal attack.
            switch (weapon_type) {
                .pierce => {
                    name = "player_pierce_cardinal"[0..];
                },

                .slash => {
                    name = "player_slash_cardinal"[0..];
                },

                .blunt => {
                    name = "player_blunt_cardinal"[0..];
                },
            }
        }

        var hit_animation = try gui.display.animation(name, hit_pos, gui.game.config.attack_animation_speed);
        try gui.state.effects.append(Effect.animationEffect(hit_animation));
    }

    fn startLevel(gui: *Gui) !void {
        try gui.assignAllIdleAnimations();
        gui.state.map_window_center = gui.game.level.entities.pos.get(entities.Entities.player_id);
        gui.state.console_log.clear();
        gui.state.effects.clearRetainingCapacity();
        gui.state.particles.clearRetainingCapacity();
    }

    fn endTurn(gui: *Gui) !void {
        try gui.assignAllIdleAnimations();
        gui.state.turn_count += 1;
    }

    fn moveEntity(gui: *Gui, id: Id, pos: Pos) !void {
        // Remove the animation, so the idle will be replayed in the new location.
        //gui.state.animation.remove(id);
        if (gui.state.animation.getPtrOrNull(id)) |anim| {
            anim.position = pos;
        }

        // When moving the player, update the map window with the currently configured parameters.
        if (id == entities.Entities.player_id) {
            gui.state.map_window_center = try mapWindowUpdate(
                gui.state.map_window_center,
                pos,
                gui.game.config.map_window_edge,
                gui.game.config.map_window_dist,
                gui.game.level.map.dims(),
            );
        }
    }

    fn cursorEnd(gui: *Gui) void {
        gui.state.cursor_animation.?.alpha = Tween.init(255, 0, gui.game.config.cursor_fade_seconds, gui.game.config.cursor_easing);
    }

    fn cursorStart(gui: *Gui, pos: Pos) !void {
        // Update cursor easing in case it was set in the config file.
        const name = try gui.display.lookupSpritekey("targeting");
        const sprite_anim = SpriteAnimation.singleFrame(name);
        gui.state.cursor_animation = Animation.init(sprite_anim, Color.white(), pos);
        gui.state.cursor_animation.?.alpha = Tween.init(0, 255, gui.game.config.cursor_fade_seconds, gui.game.config.cursor_easing);
    }

    fn cursorMove(gui: *Gui, pos: Pos) void {
        if (gui.game.config.cursor_move_seconds > 0) {
            const current_pos = gui.state.cursor_animation.?.position;
            const x = @intToFloat(f32, current_pos.x);
            const y = @intToFloat(f32, current_pos.y);
            const new_x = @intToFloat(f32, pos.x);
            const new_y = @intToFloat(f32, pos.y);
            gui.state.cursor_animation.?.x = Tween.init(x, new_x, gui.game.config.cursor_move_seconds, gui.game.config.cursor_easing);
            gui.state.cursor_animation.?.y = Tween.init(y, new_y, gui.game.config.cursor_move_seconds, gui.game.config.cursor_easing);
        }

        gui.state.cursor_animation.?.position = pos;
    }

    pub fn assignAllIdleAnimations(gui: *Gui) !void {
        for (gui.game.level.entities.name.ids.items) |id| {
            var anim: Animation = undefined;

            switch (gui.game.level.entities.name.get(id)) {
                .player => {
                    const stance = getSheetStance(gui.game.level.entities.stance.get(id));
                    const facing = gui.game.level.entities.facing.get(id);
                    const name = gui.game.level.entities.name.get(id);

                    const sheet_direction = sheetDirection(facing);
                    var name_str = @tagName(name);
                    var stance_str = @tagName(stance);
                    var direction_str = @tagName(sheet_direction);

                    var sheet_name_buf: [128]u8 = undefined;
                    var sheet_name = try std.fmt.bufPrint(&sheet_name_buf, "{s}_{s}_{s}", .{
                        utils.baseName(name_str),
                        utils.baseName(stance_str),
                        utils.baseName(direction_str),
                    });

                    var char_index: usize = 0;
                    while (char_index < sheet_name.len) : (char_index += 1) {
                        sheet_name[char_index] = std.ascii.toLower(sheet_name[char_index]);
                    }

                    const pos = gui.game.level.entities.pos.get(id);
                    anim = try gui.display.animation(sheet_name, pos, gui.game.config.idle_speed);
                    anim.repeat = true;
                    anim.sprite_anim.sprite.flip_horiz = needsFlipHoriz(facing);
                },

                .pawn => {
                    const facing = gui.game.level.entities.facing.get(id);
                    switch (facing) {
                        .left => anim = gui.simpleAnimation("pawn_standing_right", id),
                        .right => anim = gui.simpleAnimation("pawn_standing_right", id),
                        .up => anim = gui.simpleAnimation("pawn_standing_up", id),
                        .down => anim = gui.simpleAnimation("pawn_standing_down", id),
                        .downLeft => anim = gui.simpleAnimation("pawn_standing_downright", id),
                        .downRight => anim = gui.simpleAnimation("pawn_standing_downright", id),
                        .upLeft => anim = gui.simpleAnimation("pawn_standing_upright", id),
                        .upRight => anim = gui.simpleAnimation("pawn_standing_upright", id),
                    }
                    anim.sprite_anim.sprite.flip_horiz = needsFlipHoriz(facing);
                },

                .rook => {
                    const facing = gui.game.level.entities.facing.get(id);
                    switch (facing) {
                        .left => anim = gui.simpleAnimation("rook_standing_right", id),
                        .right => anim = gui.simpleAnimation("rook_standing_right", id),
                        .up => anim = gui.simpleAnimation("rook_standing_up", id),
                        .down => anim = gui.simpleAnimation("rook_standing_down", id),
                        .downLeft => anim = gui.simpleAnimation("rook_standing_downright", id),
                        .downRight => anim = gui.simpleAnimation("rook_standing_downright", id),
                        .upLeft => anim = gui.simpleAnimation("rook_standing_upright", id),
                        .upRight => anim = gui.simpleAnimation("rook_standing_upright", id),
                    }
                    anim.sprite_anim.sprite.flip_horiz = needsFlipHoriz(facing);
                },

                .gol => {
                    const facing = gui.game.level.entities.facing.get(id);
                    switch (facing) {
                        .left => anim = gui.simpleAnimation("gol_standing_right", id),
                        .right => anim = gui.simpleAnimation("gol_standing_right", id),
                        .up => anim = gui.simpleAnimation("gol_standing_up", id),
                        .down => anim = gui.simpleAnimation("gol_standing_down", id),
                        .downLeft => anim = gui.simpleAnimation("gol_standing_downright", id),
                        .downRight => anim = gui.simpleAnimation("gol_standing_downright", id),
                        .upLeft => anim = gui.simpleAnimation("gol_standing_upright", id),
                        .upRight => anim = gui.simpleAnimation("gol_standing_upright", id),
                    }
                    anim.sprite_anim.sprite.flip_horiz = needsFlipHoriz(facing);
                },

                .smoke => anim = gui.simpleAnimation("smoke", id),

                .stone => anim = gui.simpleAnimation("stone", id),

                .smokeBomb => anim = gui.simpleAnimation("smoke_bomb", id),

                .seedCache => anim = gui.simpleAnimation("seed_pouch", id),

                .seedOfStone => anim = gui.simpleAnimation("seed", id),

                .dagger => anim = gui.simpleAnimation("dagger", id),

                .sword => anim = gui.simpleAnimation("sword", id),

                .teleporter => anim = gui.simpleAnimation("seed_pouch", id),

                .shield => anim = gui.simpleAnimation("shield", id),

                .spear => anim = gui.simpleAnimation("spear", id),

                .khopesh => anim = gui.simpleAnimation("khopesh", id),

                .axe => anim = gui.simpleAnimation("axe", id),

                .hammer => anim = gui.simpleAnimation("hammer", id),

                .sling => anim = gui.simpleAnimation("sling", id),

                else => {
                    continue;
                },
            }

            // Don't assign the animation if it is identical to the previous one.
            if (gui.state.animation.getOrNull(id)) |prev_anim| {
                if (prev_anim.sprite_anim.sprite.eql(anim.sprite_anim.sprite))
                    continue;
            }

            // Apply the animation to the current entity.
            try gui.state.animation.insert(id, anim);
        }
    }

    fn simpleAnimation(gui: *Gui, name: []const u8, id: Id) Animation {
        const pos = gui.game.level.entities.pos.get(id);
        var anim = try gui.display.animation(name, pos, gui.game.config.idle_speed);
        anim.repeat = true;
        return anim;
    }

    pub fn drawPanels(gui: *Gui, delta_ticks: u64) !void {
        var painter = Painter{
            .sprites = &gui.display.sprites.sheets,
            .strings = &gui.display.strings,
            .drawcmds = &gui.panels.level.drawcmds,
            .area = gui.panels.level.panel.getRect(),
            .state = &gui.state,
            .dt = delta_ticks,
        };
        try rendering.renderLevel(&gui.game, &painter);
        gui.display.clear(&gui.panels.level);
        gui.display.draw(&gui.panels.level);

        // Render health and energy pips.
        painter.retarget(&gui.panels.pip.drawcmds, gui.panels.pip.panel.getRect());
        try rendering.renderPips(&gui.game, &painter);
        gui.display.clear(&gui.panels.pip);
        gui.display.draw(&gui.panels.pip);

        // Render current player information.
        painter.retarget(&gui.panels.player.drawcmds, gui.panels.player.panel.getRect());
        try rendering.renderPlayer(&gui.game, &painter, gui.allocator);
        gui.display.clear(&gui.panels.player);
        gui.display.draw(&gui.panels.player);

        // Render current inventory information.
        painter.retarget(&gui.panels.inventory.drawcmds, gui.panels.inventory.panel.getRect());
        try rendering.renderInventory(&gui.game, &painter, gui.allocator);
        gui.display.clear(&gui.panels.inventory);
        gui.display.draw(&gui.panels.inventory);

        // Render message log or info of the entity under the cursor.
        painter.retarget(&gui.panels.info.drawcmds, gui.panels.info.panel.getRect());
        try rendering.renderInfo(&gui.game, &painter);
        gui.display.clear(&gui.panels.info);
        gui.display.draw(&gui.panels.info);
    }

    pub fn placePanels(gui: *Gui) void {
        const map_area = mapWindowArea(gui.game.level.map.dims(), gui.state.map_window_center, gui.game.config.map_window_dist);

        gui.display.clear(&gui.panels.screen);
        gui.display.fitTexture(&gui.panels.screen, gui.panels.level_area, &gui.panels.level, map_area);
        gui.display.stretchTexture(&gui.panels.screen, gui.panels.pip_area, &gui.panels.pip, gui.panels.pip.panel.getRect());
        gui.display.stretchTexture(&gui.panels.screen, gui.panels.player_area, &gui.panels.player, gui.panels.player.panel.getRect());
        gui.display.stretchTexture(&gui.panels.screen, gui.panels.inventory_area, &gui.panels.inventory, gui.panels.inventory.panel.getRect());
        gui.display.stretchTexture(&gui.panels.screen, gui.panels.info_area, &gui.panels.info, gui.panels.info.panel.getRect());
    }

    pub fn drawOverlay(gui: *Gui) !void {
        const color = Color.init(0xcd, 0xb4, 0x96, 255);

        const offset: f32 = 0.5;
        const player_panel_pos = gui.panels.player_area.position();
        const player_panel_width = @intCast(u32, gui.panels.player_area.width);
        const player_panel_height = @intCast(u32, gui.panels.player_area.height);
        try gui.panels.screen.drawcmds.append(DrawCmd.rect(player_panel_pos, player_panel_width, player_panel_height, offset, false, color));

        const screen_panel_width = @intCast(u32, gui.panels.screen.panel.getRect().width);
        const screen_panel_height = @intCast(u32, gui.panels.player.panel.getRect().height);
        try gui.panels.screen.drawcmds.append(DrawCmd.rect(player_panel_pos, screen_panel_width, screen_panel_height, offset, false, color));

        const info_panel_pos = gui.panels.info_area.position();
        const info_panel_width = @intCast(u32, gui.panels.info_area.width);
        const info_panel_height = @intCast(u32, gui.panels.info_area.height);
        try gui.panels.screen.drawcmds.append(DrawCmd.rect(info_panel_pos, info_panel_width, info_panel_height, offset, false, color));

        const section_name_scale: f32 = 1.0;
        const text_color = Color.init(0, 0, 0, 255);
        try gui.panels.screen.drawcmds.append(DrawCmd.textJustify("player", .center, gui.panels.player_area.position(), text_color, color, @intCast(u32, gui.panels.player_area.width), section_name_scale));
        try gui.panels.screen.drawcmds.append(DrawCmd.textJustify("inventory", .center, gui.panels.inventory_area.position(), text_color, color, @intCast(u32, gui.panels.inventory_area.width), section_name_scale));
        try gui.panels.screen.drawcmds.append(DrawCmd.textJustify("message log", .center, gui.panels.info_area.position(), text_color, color, @intCast(u32, gui.panels.info_area.width), section_name_scale));

        gui.display.draw(&gui.panels.screen);
    }

    pub fn drawPlaying(gui: *Gui, delta_ticks: u64) !void {
        try gui.drawPanels(delta_ticks);
        gui.placePanels();
        try gui.drawOverlay();
    }

    pub fn drawSplash(gui: *Gui) !void {
        gui.display.clear(&gui.panels.screen);
        const color = Color.init(255, 255, 255, 255);

        const key = gui.display.strings.toKey(gui.game.settings.splash.slice());
        const splash_sheet = gui.display.sprites.fromKey(key);
        const splash_sprite = splash_sheet.sprite();

        const screen_rect = gui.panels.screen.panel.getPixelRect();
        const sprite_area = splash_sheet.spriteSrc(0);

        const screen_pixel_dims = gui.panels.screen.panel.cellDims();

        const dst_pixel_area = screen_rect.fitWithin(sprite_area);
        const dst_area = dst_pixel_area.scaleXY(
            1.0 / @intToFloat(f32, screen_pixel_dims.width),
            1.0 / @intToFloat(f32, screen_pixel_dims.height),
        );

        try gui.panels.screen.drawcmds.append(
            DrawCmd.spriteScaled(
                splash_sprite,
                @intToFloat(f32, dst_area.width),
                .center,
                color,
                Pos.init(@intCast(i32, dst_area.x_offset), @intCast(i32, dst_area.y_offset)),
            ),
        );
        gui.display.draw(&gui.panels.screen);
    }

    pub fn draw(gui: *Gui, delta_ticks: u64) !void {
        if (gui.game.settings.state == .splash) {
            try gui.drawSplash();
        } else {
            try gui.drawPlaying(delta_ticks);
        }

        gui.display.present(&gui.panels.screen);

        for (gui.state.animation.ids.items) |id| {
            _ = gui.state.animation.getPtr(id).step(delta_ticks);
        }

        var effectIndex: usize = 0;
        while (effectIndex < gui.state.effects.items.len) {
            const continue_animating = gui.state.effects.items[effectIndex].step(delta_ticks);
            if (!continue_animating) {
                _ = gui.state.effects.swapRemove(effectIndex);
            } else {
                effectIndex += 1;
            }
        }
    }
};

pub const Panels = struct {
    screen: TexturePanel,

    level: TexturePanel,
    level_area: Rect,

    player: TexturePanel,
    player_area: Rect,

    pip: TexturePanel,
    pip_area: Rect,

    info: TexturePanel,
    info_area: Rect,

    menu: TexturePanel,
    menu_area: Rect,

    help: TexturePanel,
    help_area: Rect,

    inventory: TexturePanel,
    inventory_area: Rect,

    pub fn init(width: usize, height: usize, disp: *Display, allocator: Allocator) !Panels {
        // Set up screen and its area.
        const screen_num_pixels = Dims.init(width, height);
        const screen_dims = Dims.init(SCREEN_CELLS_WIDTH, SCREEN_CELLS_HEIGHT);
        const screen_panel = Panel.init(screen_num_pixels, screen_dims);
        const screen_texture_panel = try disp.texturePanel(screen_panel, allocator);

        // Lay out panels within the screen.
        const screen_area = Rect.init(screen_dims.width, screen_dims.height);
        const top_bottom_split = screen_area.splitBottom(@intCast(usize, UI_CELLS_BOTTOM));

        const pip_map_area = top_bottom_split.first.splitTop(@intCast(usize, UI_CELLS_TOP));
        const pip_area = pip_map_area.first;
        const map_area = pip_map_area.second;

        const player_right_area = top_bottom_split.second.splitLeft(screen_area.width / 4);
        const player_area = player_right_area.first;
        const inventory_info_area = player_right_area.second.splitLeft(player_right_area.second.width / 2);
        const inventory_area = inventory_info_area.first;
        const info_area = inventory_info_area.second;

        const menu_area = screen_area.centered(@floatToInt(usize, @intToFloat(f32, info_area.width) * 1.2), @floatToInt(usize, @intToFloat(f32, info_area.height) * 1.2));
        const help_area = screen_area.centered(@floatToInt(usize, @intToFloat(f32, screen_area.width) * 0.8), @floatToInt(usize, @intToFloat(f32, screen_area.height) * 0.9));

        // Create the misc panels.
        const menu_panel = screen_panel.subpanel(menu_area);
        const menu_texture_panel = try disp.texturePanel(menu_panel, allocator);

        const pip_panel = screen_panel.subpanel(pip_area);
        const pip_texture_panel = try disp.texturePanel(pip_panel, allocator);

        const info_panel = screen_panel.subpanel(info_area);
        const info_texture_panel = try disp.texturePanel(info_panel, allocator);

        const help_panel = screen_panel.subpanel(help_area);
        const help_texture_panel = try disp.texturePanel(help_panel, allocator);

        const player_panel = screen_panel.subpanel(player_area);
        const player_texture_panel = try disp.texturePanel(player_panel, allocator);

        const inventory_panel = screen_panel.subpanel(inventory_area);
        const inventory_texture_panel = try disp.texturePanel(inventory_panel, allocator);

        // Create the map panel.
        const level_num_pixels = Dims.init(MAX_MAP_WIDTH * sprite.FONT_WIDTH, MAX_MAP_HEIGHT * sprite.FONT_HEIGHT);
        const level_panel = Panel.init(level_num_pixels, Dims.init(MAX_MAP_WIDTH, MAX_MAP_HEIGHT));
        const level_texture_panel = try disp.texturePanel(level_panel, allocator);

        return Panels{
            .screen = screen_texture_panel,
            .level = level_texture_panel,
            .level_area = map_area,
            .player = player_texture_panel,
            .player_area = player_area,
            .info = info_texture_panel,
            .info_area = info_area,
            .inventory = inventory_texture_panel,
            .inventory_area = inventory_area,
            .help = help_texture_panel,
            .help_area = help_area,
            .pip = pip_texture_panel,
            .pip_area = pip_area,
            .menu = menu_texture_panel,
            .menu_area = menu_area,
        };
    }

    pub fn deinit(panels: *Panels) void {
        panels.screen.deinit();
        panels.level.deinit();
    }
};

fn mapWindowArea(dims: Dims, center: Pos, dist: i32) Rect {
    const up_left_edge = dims.clamp(Pos.init(center.x - dist, center.y - dist));
    const width = std.math.min(2 * dist + 1, dims.width);
    const height = std.math.min(2 * dist + 1, dims.height);
    return Rect.initAt(@intCast(usize, up_left_edge.x), @intCast(usize, up_left_edge.y), width, height);
}

/// A map window controls the part of the map around the player that is visible
/// during a turn. This can follow the player, it can show a map that always gives
/// a little buffer around the player, or it can just display the entire map (effectively
/// disabling the map window concept).
/// If edge_dist or dist are negative the following behavior is disabled. If dist is
/// negative the whole map will be displayed.
fn mapWindowUpdate(pos: Pos, new_pos: Pos, edge_dist: i32, dist: i32, map_dims: Dims) !Pos {
    var center = pos;
    if (dist < 0 or edge_dist < 0) {
        center = new_pos;
    } else {
        // Move the map window in x and y.
        // However, only move the map window if the position is not next to the edge of the map.
        const needs_move_dist = dist - edge_dist;

        const x_dist = new_pos.x - center.x;
        const x_abs_dist = try std.math.absInt(x_dist);
        if (x_abs_dist > needs_move_dist) {
            const x_map_edge_dist = std.math.min(new_pos.x, @intCast(i32, map_dims.width) - new_pos.x);
            if (x_map_edge_dist >= edge_dist) {
                center.x = center.x + ((x_abs_dist - needs_move_dist) * std.math.sign(x_dist));
            }
        }

        const y_dist = new_pos.y - center.y;
        const y_abs_dist = try std.math.absInt(y_dist);
        if (y_abs_dist > needs_move_dist) {
            const y_map_edge_dist = std.math.min(new_pos.y, @intCast(i32, map_dims.height) - new_pos.y);
            if (y_map_edge_dist >= edge_dist) {
                center.y = center.y + ((y_abs_dist - needs_move_dist) * std.math.sign(y_dist));
            }
        }
    }

    return center;
}

test "map window centered" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(3, 3);
    const center = try mapWindowUpdate(start_center, Pos.init(4, 3), 1, 1, map_dims);
    try std.testing.expectEqual(Pos.init(4, 3), center);
}

test "map window not centered" {
    const map_dims = Dims.init(10, 10);
    // Edge distance of 0 means the player can move within the extra tile without recentering.
    const start_center = Pos.init(3, 3);
    const center = try mapWindowUpdate(start_center, Pos.init(4, 3), 0, 1, map_dims);
    try std.testing.expectEqual(Pos.init(3, 3), center);
}

test "map window follow no window" {
    const map_dims = Dims.init(10, 10);
    {
        const start_center = Pos.init(3, 3);
        const center = try mapWindowUpdate(start_center, Pos.init(4, 3), 1, -1, map_dims);
        try std.testing.expectEqual(Pos.init(4, 3), center);
    }

    {
        const start_center = Pos.init(3, 3);
        const center = try mapWindowUpdate(start_center, Pos.init(4, 3), -1, 1, map_dims);
        try std.testing.expectEqual(Pos.init(4, 3), center);
    }
}

test "map window follow with window" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(3, 3);
    const center = try mapWindowUpdate(start_center, Pos.init(4, 3), 0, 0, map_dims);
    try std.testing.expectEqual(Pos.init(4, 3), center);
}

test "map window no follow x left edge" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(3, 3);
    const center = try mapWindowUpdate(start_center, Pos.init(1, 3), 2, 3, map_dims);
    try std.testing.expectEqual(Pos.init(3, 3), center);
}

test "map window no follow x right edge" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(8, 3);
    const center = try mapWindowUpdate(start_center, Pos.init(9, 3), 2, 3, map_dims);
    try std.testing.expectEqual(Pos.init(8, 3), center);
}

test "map window no follow y top edge" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(3, 8);
    const center = try mapWindowUpdate(start_center, Pos.init(3, 9), 2, 3, map_dims);
    try std.testing.expectEqual(Pos.init(3, 8), center);
}

test "map window no follow y bottom edge" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(3, 3);
    const center = try mapWindowUpdate(start_center, Pos.init(3, 2), 2, 3, map_dims);
    try std.testing.expectEqual(Pos.init(3, 3), center);
}

pub const ConsoleLog = struct {
    pub const num_msgs: usize = 6;
    pub const msg_len: usize = 32;

    log: [num_msgs * msg_len]u8 = [_]u8{0} ** (num_msgs * msg_len),
    slices: [num_msgs][]u8,
    turns: [num_msgs]usize,
    index: usize = 0,

    pub fn init() ConsoleLog {
        var console_log = ConsoleLog{ .slices = undefined, .turns = undefined };
        console_log.clear();
        return console_log;
    }

    pub fn queue(console_log: *ConsoleLog, entities_ptr: *const Entities, msg: Msg, turn: usize) !void {
        const start = console_log.index * msg_len;
        const end = start + msg_len;

        const str = try msg.consoleMessage(entities_ptr, console_log.log[start..end]);

        if (str.len > 0) {
            console_log.slices[console_log.index] = str;
            console_log.turns[console_log.index] = turn;
            console_log.index = (console_log.index + 1) % num_msgs;
        }
    }

    pub fn clear(console_log: *ConsoleLog) void {
        var index: usize = 0;
        while (index < num_msgs) : (index += 1) {
            console_log.slices[index] = &.{};
            console_log.turns[index] = 0;
        }
    }
};

pub const DisplayState = struct {
    animation: Comp(Animation),
    cursor_animation: ?Animation = null,
    map_window_center: Pos,
    turn_count: usize,
    console_log: ConsoleLog,
    effects: ArrayList(Effect),
    particles: ArrayList(Particle),

    pub fn init(allocator: Allocator) DisplayState {
        var state: DisplayState = undefined;

        state.cursor_animation = null;
        state.map_window_center = Pos.init(0, 0);
        state.turn_count = 0;
        state.console_log = ConsoleLog.init();
        state.effects = ArrayList(Effect).init(allocator);
        state.particles = ArrayList(Particle).init(allocator);

        comptime var names = entities.compNames(DisplayState);
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

fn sheetDirection(direction: Direction) Direction {
    return switch (direction) {
        Direction.up => .up,
        Direction.down => .down,
        Direction.left => .right,
        Direction.right => .right,
        Direction.upRight => .upRight,
        Direction.upLeft => .upRight,
        Direction.downRight => .downRight,
        Direction.downLeft => .downRight,
    };
}

fn needsFlipHoriz(direction: Direction) bool {
    return switch (direction) {
        Direction.up => false,
        Direction.down => false,
        Direction.left => true,
        Direction.right => false,
        Direction.upRight => false,
        Direction.upLeft => true,
        Direction.downRight => false,
        Direction.downLeft => true,
    };
}

fn getSheetStance(stance: Stance) Stance {
    if (stance == .running) {
        return .standing;
    } else {
        return stance;
    }
}

const Particle = struct {
    start_x: f32,
    end_x: f32,
    y: f32,
    duration: u64,
    time: u64,
    sprite: Sprite,
};

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}

test "gui alloc dealloc" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const allocator = general_purpose_allocator.allocator();

    var gui = try Gui.init(0, false, allocator);
    defer gui.deinit();
}
