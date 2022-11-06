pub const comp = @import("utils/comp.zig");
pub const astar = @import("utils/astar.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
