const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const comp = utils.comp;
const Comp = comp.Comp;
const math = @import("math");
const Pos = math.pos.Pos;

const core = @import("core");

const g = @import("gui");
const Display = g.display.Display;

const drawcmd = @import("drawcmd.zig");
const DrawCmd = drawcmd.drawcmd.DrawCmd;
const Color = drawcmd.utils.Color;

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    var gui = try g.Gui.init(0, allocator);
    try gui.display.push(DrawCmd.text("Hello, drawcmd!", Pos.init(0, 0), Color.white(), 1.0));
    gui.display.present();
    std.time.sleep(1000000000);
}

test "full test set" {
    _ = @import("math");
    _ = @import("utils");
    _ = @import("board");
    _ = @import("core");
    _ = @import("drawcmd");
    _ = @import("game.zig");
    _ = @import("gui");
    _ = @import("events");
}
