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

const drawcmd = @import("drawcmd");
const DrawCmd = drawcmd.drawcmd.DrawCmd;

const rendering = @import("src/rendering.zig");

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    var gui = try g.Gui.init(0, allocator);
    defer gui.deinit();

    try gui.startLevel(7, 7);
    gui.game.level.map.set(Pos.init(1, 1), board.tile.Tile.shortLeftAndDownWall());
    gui.game.level.map.set(Pos.init(2, 2), board.tile.Tile.tallWall());

    while (try gui.step()) {
        try gui.draw();
        std.time.sleep(100000000);
    }
}
