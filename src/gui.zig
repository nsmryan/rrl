const std = @import("std");
const Allocator = std.mem.Allocator;

const g = @import("game.zig");
const Game = g.Game;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const core = @import("core");
const movement = core.movement;
const Config = core.config.Config;

const gen = @import("gen");

const rendering = @import("rendering.zig");

const game = @import("game");
const Input = game.input.Input;
const UseAction = game.actions.UseAction;
const Settings = game.actions.Settings;
const GameState = game.GameState;

pub const display = @import("gui/display.zig");
pub const keyboard = @import("gui/keyboard.zig");
pub const drawing = @import("gui/drawing.zig");
pub const sdl2 = @import("gui/sdl2.zig");

pub const Gui = struct {
    display: display.Display,
    game: Game,

    pub fn init(seed: ?u64, allocator: Allocator) !Gui {
        return Gui{
            .display = try display.Display.init(800, 640, allocator),
            .game = try Game.init(seed, allocator),
        };
    }

    pub fn deinit(gui: *Gui) void {
        gui.display.deinit();
        gui.game.deinit();
    }

    pub fn step(gui: *Gui) !bool {
        // dispatch based on state and turn InputAction into messages
        // Messages must be implemented, and include a "now" concept to simplfy use code.
        // Add a resolve function which then modifies the game based on the messages.
        //
        const ticks = sdl2.SDL_GetTicks64();
        var event: sdl2.SDL_Event = undefined;
        while (sdl2.SDL_PollEvent(&event) != 0) {
            if (keyboard.translateEvent(event)) |input_event| {
                try gui.game.step(input_event, ticks);
                try gui.draw();
            }
        }

        return gui.game.settings.state != GameState.exit;
    }

    pub fn draw(gui: *Gui) !void {
        try rendering.render(&gui.game, &gui.display.sprites.sheets, &gui.display.panel, &gui.display.drawcmds);
        gui.display.present();
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
