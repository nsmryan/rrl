const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils.zig");
const comp = utils.comp;
const line = utils.line;
const math = utils.math;
const rand = utils.rand;
const Pos = utils.pos.Pos;

const display = @import("display.zig");
const Display = display.Display;

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;
    var c = comp.Comp(u64).init(allocator);

    try c.insert(0, 10);
    try c.insert(1, 11);

    var iter = c.iter();
    std.log.info("rustrl comp {}", .{iter.next()});
    std.log.info("rustrl comp {}", .{iter.next()});

    std.debug.print("init display\n", .{});
    var disp = try Display.init(800, 600);
    std.debug.print("display started\n", .{});
    disp.present();
    std.debug.print("display presented\n", .{});
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
