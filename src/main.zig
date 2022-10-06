const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils.zig");
const comp = utils.comp;
const line = utils.line;
const math = utils.math;
const rand = utils.rand;
const Pos = utils.pos.Pos;

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;
    var c = comp.Comp(u64).init(allocator);

    try c.insert(0, 10);
    try c.insert(1, 11);

    var iter = c.iter();
    std.log.info("rustrl comp {}", .{iter.next()});
    std.log.info("rustrl comp {}", .{iter.next()});
}

test "full test set" {
    _ = @import("utils.zig");
    _ = @import("board.zig");
    _ = @import("core.zig");
    _ = @import("game.zig");
}
