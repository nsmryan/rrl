const std = @import("std");

pub const comp = @import("utils/comp.zig");
pub usingnamespace comp;

pub const astar = @import("utils/astar.zig");
pub usingnamespace astar;

test "utils test set" {
    _ = @import("utils/comp.zig");
    _ = @import("utils/astar.zig");
}
