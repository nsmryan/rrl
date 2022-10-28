const std = @import("std");
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

const g = @import("game.zig");
const Game = g.Game;

const events = @import("events");
const Input = events.input.Input;

pub const display = @import("gui/display.zig");
pub const input = @import("gui/keyboard.zig");
pub const drawing = @import("gui/drawing.zig");
pub const sdl2 = @import("gui/sdl2.zig");

pub const Gui = struct {
    display: display.Display,
    input: Input,
    game: Game,

    pub fn init(seed: u64, allocator: Allocator) !Gui {
        var rng = RndGen.init(seed);
        return Gui{
            .display = try display.Display.init(800, 640),
            .input = Input.init(allocator),
            .game = Game.init(rng.random(), allocator),
        };
    }
};

test "gui test set" {
    _ = @import("gui/display.zig");
    _ = @import("gui/keyboard.zig");
    _ = @import("gui/drawing.zig");
    _ = @import("gui/sdl2.zig");
}
