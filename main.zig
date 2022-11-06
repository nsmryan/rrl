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

const drawcmd = @import("drawcmd");
const DrawCmd = drawcmd.drawcmd.DrawCmd;
const Color = drawcmd.utils.Color;

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    var gui = try g.Gui.init(0, allocator);
    try gui.display.push(DrawCmd.text("Hello, drawcmd!", Pos.init(0, 0), Color.white(), 1.0));
    gui.display.present();

    while (try gui.step()) {
        std.time.sleep(100000000);
    }
}
