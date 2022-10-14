const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const comp = utils.comp;
const math = @import("math");
const Pos = math.pos.Pos;

const display = @import("display.zig");
const Display = display.Display;

const drawcmd = @import("drawcmd.zig");
const DrawCmd = drawcmd.drawcmd.DrawCmd;
const Color = drawcmd.utils.Color;

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;
    var c = comp.Comp(u64).init(allocator);

    try c.insert(0, 10);
    try c.insert(1, 11);

    var iter = c.iter();
    std.log.info("rustrl comp {}", .{iter.next()});
    std.log.info("rustrl comp {}", .{iter.next()});

    var disp = try Display.init(800, 600);
    try disp.push(DrawCmd.text("Hello, drawcmd!", Pos.init(10, 10), Color.white(), 1.0));
    disp.present();
    std.time.sleep(1000000000);
}

test "full test set" {
    _ = @import("math");
    _ = @import("utils");
    _ = @import("board");
    _ = @import("core");
    _ = @import("drawcmd");
    _ = @import("game.zig");
    _ = @import("drawing.zig");
    _ = @import("display.zig");
}
