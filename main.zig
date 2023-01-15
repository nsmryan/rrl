const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const comp = utils.comp;
const Comp = comp.Comp;

const math = @import("math");
const Pos = math.pos.Pos;
const Color = math.utils.Color;

const board = @import("board");
const Map = board.map.Map;

const core = @import("core");

const g = @import("gui");
const Display = g.display.Display;
const rendering = g.rendering;

const drawcmd = @import("drawcmd");
const DrawCmd = drawcmd.drawcmd.DrawCmd;

const sdl2 = g.sdl2;

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    const has_profiling = @import("build_options").remotery;
    var gui = try g.Gui.init(0, has_profiling, allocator);
    defer gui.deinit();

    try gui.game.startLevel(21, 21);
    gui.game.level.map.set(Pos.init(1, 1), board.tile.Tile.shortLeftAndDownWall());
    gui.game.level.map.set(Pos.init(2, 2), board.tile.Tile.tallWall());
    try gui.resolveMessages();

    var ticks = sdl2.SDL_GetTicks64();
    while (try gui.step(ticks)) {
        std.time.sleep(1000000000 / gui.game.config.frame_rate);
        ticks = sdl2.SDL_GetTicks64();
    }
}
