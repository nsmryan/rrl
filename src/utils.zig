pub const comp = @import("utils/comp.zig");
pub const astar = @import("utils/astar.zig");
pub const intern = @import("utils/intern.zig");
pub const timer = @import("utils/timer.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
