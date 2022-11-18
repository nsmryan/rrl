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

const gen = @import("gen");

const rendering = @import("rendering.zig");

const engine = @import("engine");
const Game = engine.game.Game;
const Input = engine.input.Input;
const InputEvent = engine.input.InputEvent;
const UseAction = engine.actions.UseAction;
const Settings = engine.actions.Settings;
const GameState = engine.settings.GameState;

const drawcmd = @import("drawcmd");
const SpriteAnimation = drawcmd.sprite.SpriteAnimation;

pub const display = @import("gui/display.zig");
pub const keyboard = @import("gui/keyboard.zig");
pub const drawing = @import("gui/drawing.zig");
pub const sdl2 = @import("gui/sdl2.zig");

pub const Gui = struct {
    display: display.Display,
    game: Game,
    animations: Comp(SpriteAnimation),

    pub fn init(seed: u64, allocator: Allocator) !Gui {
        return Gui{
            .display = try display.Display.init(800, 640, allocator),
            .game = try Game.init(seed, allocator),
            .animations = Comp(SpriteAnimation).init(allocator),
        };
    }

    pub fn deinit(gui: *Gui) void {
        gui.display.deinit();
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
        gui.resolveMessages();
    }

    pub fn resolveMessages(gui: *Gui) void {
        for (gui.game.log.all.items) |msg| {
            switch (msg) {
                .spawn => |args| {
                    _ = args;
                    //gui.animations.set(args.id, animationFromName(gui.display.sprites, args.name));
                },

                else => {},
            }
        }
    }

    pub fn draw(gui: *Gui) !void {
        try rendering.render(&gui.game, &gui.display.sprites.sheets, &gui.display.drawcmds);
        gui.display.present(gui.game.level.map.dims());
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
