pub const input = @import("events/input.zig");
pub const actions = @import("events/actions.zig");

//test "events test set" {
//    _ = @import("events/input.zig");
//    _ = @import("events/actions.zig");
//}
comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
