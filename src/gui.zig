const std = @import("std");

const Allocator = std.mem.Allocator;

const utils = @import("utils");
const Comp = utils.comp.Comp;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const core = @import("core");
const movement = core.movement;
const Config = core.config.Config;
const entities = core.entities;
const Stance = entities.Stance;
const Name = entities.Name;

const gen = @import("gen");

const rendering = @import("rendering.zig");
const Painter = rendering.Painter;

const board = @import("board");
const Map = board.map.Map;

const engine = @import("engine");
const Game = engine.game.Game;
const Input = engine.input.Input;
const InputEvent = engine.input.InputEvent;
const UseAction = engine.actions.UseAction;
const Settings = engine.actions.Settings;
const GameState = engine.settings.GameState;

const drawcmd = @import("drawcmd");
const sprite = drawcmd.sprite;
const SpriteAnimation = sprite.SpriteAnimation;

pub const display = @import("gui/display.zig");
pub const keyboard = @import("gui/keyboard.zig");
pub const drawing = @import("gui/drawing.zig");
pub const sdl2 = @import("gui/sdl2.zig");

pub const Gui = struct {
    display: display.Display,
    game: Game,
    state: DisplayState,
    allocator: Allocator,

    pub fn init(seed: u64, allocator: Allocator) !Gui {
        return Gui{
            .display = try display.Display.init(800, 640, allocator),
            .game = try Game.init(seed, allocator),
            .state = DisplayState.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(gui: *Gui) void {
        gui.display.deinit();
        gui.state.deinit();
        gui.game.deinit();
    }

    pub fn step(gui: *Gui) !bool {
        const ticks = sdl2.SDL_GetTicks64();
        var event: sdl2.SDL_Event = undefined;
        while (sdl2.SDL_PollEvent(&event) != 0) {
            if (keyboard.translateEvent(event)) |input_event| {
                try gui.inputEvent(input_event, ticks);
            }
        }

        // Draw whether or not there is an event to update animations, effects, etc.
        try gui.draw();

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
                .move => |args| try gui.state.pos.insert(args.id, args.pos),
                .startLevel => try gui.assignAllIdleAnimations(),
                .endTurn => try gui.assignAllIdleAnimations(),

                else => {},
            }
        }
    }

    pub fn assignAllIdleAnimations(gui: *Gui) !void {
        for (gui.state.name.ids.items) |id| {
            switch (gui.state.name.get(id)) {
                .player => {
                    const stance = getSheetStance(gui.state.stance.get(id));
                    const facing = gui.state.facing.get(id);
                    const name = gui.state.name.get(id);

                    const sheet_direction = sheetDirection(facing);
                    var sheet_name_slice: [sprite.MAX_NAME_SIZE]u8 = undefined;
                    var sheet_name = try std.fmt.bufPrint(&sheet_name_slice, "{}_{}_{}", .{ name, stance, sheet_direction });

                    var anim = try gui.display.animation(sheet_name, gui.game.config.idle_speed);
                    anim.looped = true;
                    try gui.state.animations.insert(id, anim);
                    // NOTE(implement) likely this needs to be added back in
                    //anim.flip_horiz = needsFlipHoriz(direction);
                },

                else => {},
            }
        }
    }

    pub fn draw(gui: *Gui) !void {
        var painter = Painter{ .sprites = &gui.display.sprites.sheets, .strings = &gui.display.strings, .drawcmds = &gui.display.drawcmds };
        try rendering.render(&gui.game, &painter);
        gui.display.present(gui.game.level.map.dims());
    }
};

pub const DisplayState = struct {
    pos: Comp(Pos),
    stance: Comp(Stance),
    name: Comp(Name),
    facing: Comp(Direction),
    animations: Comp(SpriteAnimation),

    pub fn init(allocator: Allocator) DisplayState {
        var state: DisplayState = undefined;
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

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}

test "gui alloc dealloc" {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const allocator = general_purpose_allocator.allocator();

    var gui = try Gui.init(0, allocator);
    defer gui.deinit();
}

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
