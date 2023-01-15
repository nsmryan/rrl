const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;

const Allocator = std.mem.Allocator;

const utils = @import("utils");
const Comp = utils.comp.Comp;
const Id = utils.comp.Id;
const Timer = utils.timer.Timer;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;
const Tween = math.tweening.Tween;
const Dims = math.utils.Dims;
const Color = math.utils.Color;

const core = @import("core");
const movement = core.movement;
const Config = core.config.Config;
const entities = core.entities;
const Stance = entities.Stance;
const Name = entities.Name;

const gen = @import("gen");

const board = @import("board");
const Map = board.map.Map;

const engine = @import("engine");
const Game = engine.game.Game;
const Input = engine.input.Input;
const InputEvent = engine.input.InputEvent;
const UseAction = engine.actions.UseAction;
const Settings = engine.actions.Settings;
const GameState = engine.settings.GameState;

const drawing = @import("drawing");
const sprite = drawing.sprite;
const Animation = drawing.animation.Animation;
const SpriteAnimation = sprite.SpriteAnimation;
const Panel = drawing.panel.Panel;
const Area = drawing.area.Area;
const DrawCmd = drawing.drawcmd.DrawCmd;

const prof = @import("prof");

pub const display = @import("display.zig");
pub const Display = display.Display;
pub const TexturePanel = display.TexturePanel;
pub const keyboard = @import("keyboard.zig");
pub const canvas = @import("canvas.zig");
pub const sdl2 = @import("sdl2.zig");
pub const rendering = @import("rendering.zig");
const Painter = rendering.Painter;

const Texture = sdl2.SDL_Texture;

pub const MAX_MAP_WIDTH: usize = 80;
pub const MAX_MAP_HEIGHT: usize = 80;

pub const SCREEN_CELLS_WIDTH: usize = 50;
pub const SCREEN_CELLS_HEIGHT: usize = 40;

pub const WINDOW_WIDTH: usize = 800;
pub const WINDOW_HEIGHT: usize = 640;

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
            }
        }
        prof.end();

        gui.ticks = ticks;

        // Draw whether or not there is an event to update animations, effects, etc.
        prof.scope("draw");
        try gui.draw(delta_ticks);
        defer prof.end();

        return gui.game.settings.state != GameState.exit;
    }

    pub fn inputEvent(gui: *Gui, input_event: InputEvent, ticks: u64) !void {
        try gui.game.step(input_event, ticks);
        try gui.resolveMessages();
    }

    pub fn resolveMessages(gui: *Gui) !void {
        for (gui.game.log.all.items) |msg| {
            switch (msg) {
                .spawn => |args| try gui.state.name.insert(args.id, args.name),
                .facing => |args| try gui.state.facing.insert(args.id, args.facing),
                .stance => |args| try gui.state.stance.insert(args.id, args.stance),
                .move => |args| try gui.moveEntity(args.id, args.pos),
                .startLevel => try gui.startLevel(),
                .endTurn => try gui.assignAllIdleAnimations(),
                .cursorStart => |args| try gui.cursorStart(args),
                .cursorEnd => gui.cursorEnd(),
                .cursorMove => |args| gui.cursorMove(args),

                else => {},
            }
        }
    }

    fn startLevel(gui: *Gui) !void {
        try gui.assignAllIdleAnimations();
        gui.state.map_window_center = gui.game.level.entities.pos.get(entities.Entities.player_id);
    }

    fn moveEntity(gui: *Gui, id: Id, pos: Pos) !void {
        try gui.state.pos.insert(id, pos);

        // Remove the animation, so the idle will be replayed in the new location.
        //gui.state.animation.remove(id);
        if (gui.state.animation.getPtrOrNull(id)) |anim| {
            anim.position = pos;
        }

        // When moving the player, update the map window with the currently configured parameters.
        if (id == entities.Entities.player_id) {
            std.debug.print("center before {}, pos {}\n", .{ gui.state.map_window_center, pos });
            gui.state.map_window_center = try map_window_update(
                gui.state.map_window_center,
                pos,
                gui.game.config.map_window_edge,
                gui.game.config.map_window_dist,
                gui.game.level.map.dims(),
            );
            std.debug.print("center after {}\n", .{gui.state.map_window_center});
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
        for (gui.state.name.ids.items) |id| {
            switch (gui.state.name.get(id)) {
                .player => {
                    const stance = getSheetStance(gui.state.stance.get(id));
                    const facing = gui.state.facing.get(id);
                    const name = gui.state.name.get(id);

                    const sheet_direction = sheetDirection(facing);
                    var name_str_buf: [128]u8 = undefined;
                    var stance_str_buf: [128]u8 = undefined;
                    var direction_str_buf: [128]u8 = undefined;
                    var name_str = try std.fmt.bufPrint(&name_str_buf, "{}", .{name});
                    var stance_str = try std.fmt.bufPrint(&stance_str_buf, "{}", .{stance});
                    var direction_str = try std.fmt.bufPrint(&direction_str_buf, "{}", .{sheet_direction});

                    var sheet_name_buf: [128]u8 = undefined;
                    var sheet_name = try std.fmt.bufPrint(&sheet_name_buf, "{s}_{s}_{s}", .{ baseName(name_str), baseName(stance_str), baseName(direction_str) });

                    var char_index: usize = 0;
                    while (char_index < sheet_name.len) : (char_index += 1) {
                        sheet_name[char_index] = std.ascii.toLower(sheet_name[char_index]);
                    }

                    const pos = gui.game.level.entities.pos.get(id);
                    var anim = try gui.display.animation(sheet_name, pos, gui.game.config.idle_speed);
                    anim.repeat = true;
                    anim.sprite_anim.sprite.flip_horiz = needsFlipHoriz(facing);

                    if (gui.state.animation.getOrNull(id)) |prev_anim| {
                        if (prev_anim.sprite_anim.sprite.eql(anim.sprite_anim.sprite))
                            continue;
                    }

                    try gui.state.animation.insert(id, anim);
                },

                else => {},
            }
        }
    }

    pub fn draw(gui: *Gui, delta_ticks: u64) !void {
        var painter = Painter{
            .sprites = &gui.display.sprites.sheets,
            .strings = &gui.display.strings,
            .drawcmds = &gui.panels.level.drawcmds,
            .state = &gui.state,
            .dt = delta_ticks,
        };
        try rendering.render(&gui.game, &painter);

        gui.display.draw(&gui.panels.level);

        const screen_area = Area.init(gui.panels.screen.panel.cells.width, gui.panels.screen.panel.cells.height);
        //const map_area = Area.init(@intCast(usize, gui.game.level.map.width), @intCast(usize, gui.game.level.map.height));
        const map_area = map_window_area(gui.game.level.map.dims(), gui.state.map_window_center, gui.game.config.map_window_dist);
        //std.debug.print("map window area {}\n", .{map_area});

        //gui.display.stretchTexture(&gui.panels.screen, screen_area, &gui.panels.level, map_area);
        gui.display.fitTexture(&gui.panels.screen, screen_area, &gui.panels.level, map_area);
        gui.display.present(&gui.panels.screen);

        for (gui.state.animation.ids.items) |id| {
            _ = gui.state.animation.getPtr(id).step(delta_ticks);
        }
    }
};

pub const Panels = struct {
    screen: TexturePanel,
    level: TexturePanel,

    pub fn init(width: usize, height: usize, disp: *Display, allocator: Allocator) !Panels {
        const screen_num_pixels = Dims.init(width, height);
        const screen_panel = Panel.init(screen_num_pixels, Dims.init(SCREEN_CELLS_WIDTH, SCREEN_CELLS_HEIGHT));
        //const screen_area = Area.init(screen_num_pixels.width, screen_num_pixels.height);
        const screen_texture_panel = try disp.texturePanel(screen_panel, allocator);

        // NOTE(implement) lay out screen areas.
        //let (top_area, bottom_area) = screen_area.split_top(canvas_panel.cells.1 as usize - UI_CELLS_BOTTOM as usize);
        //let (pip_area, map_area) = top_area.split_top(UI_CELLS_TOP as usize);
        //let (player_area, right_area) = bottom_area.split_left(canvas_panel.cells.0 as usize / 6);
        //let (inventory_area, right_area) = right_area.split_left(canvas_panel.cells.0 as usize / 2);
        //let info_area = right_area;
        //let menu_area = screen_area.centered((info_area.width as f32 * 1.5) as usize, (info_area.height as f32 * 1.5) as usize);
        //let help_area = screen_area.centered((screen_area.width as f32 * 0.8) as usize, (screen_area.height as f32 * 0.9) as usize);

        const level_num_pixels = Dims.init(MAX_MAP_WIDTH * sprite.FONT_WIDTH, MAX_MAP_HEIGHT * sprite.FONT_HEIGHT);
        const level_panel = Panel.init(level_num_pixels, Dims.init(MAX_MAP_WIDTH, MAX_MAP_HEIGHT));
        const level_texture_panel = try disp.texturePanel(level_panel, allocator);

        return Panels{ .screen = screen_texture_panel, .level = level_texture_panel };
    }

    pub fn deinit(panels: *Panels) void {
        panels.screen.deinit();
        panels.level.deinit();
    }
};

fn map_window_area(dims: Dims, center: Pos, dist: i32) Area {
    const up_left_edge = dims.clamp(Pos.init(center.x - dist, center.y - dist));
    const width = std.math.min(2 * dist + 1, dims.width);
    const height = std.math.min(2 * dist + 1, dims.height);
    return Area.initAt(@intCast(usize, up_left_edge.x), @intCast(usize, up_left_edge.y), width, height);
}

/// A map window controls the part of the map around the player that is visible
/// during a turn. This can follow the player, it can show a map that always gives
/// a little buffer around the player, or it can just display the entire map (effectively
/// disabling the map window concept).
/// If edge_dist or dist are negative the following behavior is disabled. If dist is
/// negative the whole map will be displayed.
fn map_window_update(pos: Pos, new_pos: Pos, edge_dist: i32, dist: i32, map_dims: Dims) !Pos {
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
    const center = try map_window_update(start_center, Pos.init(4, 3), 1, 1, map_dims);
    try std.testing.expectEqual(Pos.init(4, 3), center);
}

test "map window not centered" {
    const map_dims = Dims.init(10, 10);
    // Edge distance of 0 means the player can move within the extra tile without recentering.
    const start_center = Pos.init(3, 3);
    const center = try map_window_update(start_center, Pos.init(4, 3), 0, 1, map_dims);
    try std.testing.expectEqual(Pos.init(3, 3), center);
}

test "map window follow no window" {
    const map_dims = Dims.init(10, 10);
    {
        const start_center = Pos.init(3, 3);
        const center = try map_window_update(start_center, Pos.init(4, 3), 1, -1, map_dims);
        try std.testing.expectEqual(Pos.init(4, 3), center);
    }

    {
        const start_center = Pos.init(3, 3);
        const center = try map_window_update(start_center, Pos.init(4, 3), -1, 1, map_dims);
        try std.testing.expectEqual(Pos.init(4, 3), center);
    }
}

test "map window follow with window" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(3, 3);
    const center = try map_window_update(start_center, Pos.init(4, 3), 0, 0, map_dims);
    try std.testing.expectEqual(Pos.init(4, 3), center);
}

test "map window no follow x left edge" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(3, 3);
    const center = try map_window_update(start_center, Pos.init(1, 3), 2, 3, map_dims);
    try std.testing.expectEqual(Pos.init(3, 3), center);
}

test "map window no follow x right edge" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(8, 3);
    const center = try map_window_update(start_center, Pos.init(9, 3), 2, 3, map_dims);
    try std.testing.expectEqual(Pos.init(8, 3), center);
}

test "map window no follow y top edge" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(3, 8);
    const center = try map_window_update(start_center, Pos.init(3, 9), 2, 3, map_dims);
    try std.testing.expectEqual(Pos.init(3, 8), center);
}

test "map window no follow y bottom edge" {
    const map_dims = Dims.init(10, 10);
    const start_center = Pos.init(3, 3);
    const center = try map_window_update(start_center, Pos.init(3, 2), 2, 3, map_dims);
    try std.testing.expectEqual(Pos.init(3, 3), center);
}

pub const DisplayState = struct {
    pos: Comp(Pos),
    stance: Comp(Stance),
    name: Comp(Name),
    facing: Comp(Direction),
    animation: Comp(Animation),
    cursor_animation: ?Animation = null,
    map_window_center: Pos,

    pub fn init(allocator: Allocator) DisplayState {
        var state: DisplayState = undefined;
        comptime var names = entities.compNames(DisplayState);
        state.cursor_animation = null;
        state.map_window_center = Pos.init(0, 0);
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

//fn needsFlipVert(direction: Direction) bool {
//    return switch (direction) {
//        Direction.up => true,
//        Direction.down => true,
//        Direction.left => false,
//        Direction.right => true,
//        Direction.upRight => true,
//        Direction.upLeft => false,
//        Direction.downRight => true,
//        Direction.downLeft => false,
//    };
//}

fn getSheetStance(stance: Stance) Stance {
    if (stance == .running) {
        return .standing;
    } else {
        return stance;
    }
}

fn baseName(name: []const u8) []const u8 {
    if (std.mem.lastIndexOf(u8, name, ".")) |last_index| {
        return name[(last_index + 1)..];
    } else {
        return name;
    }
}

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
