pub const actions = @import("actions.zig");
pub const input = @import("input.zig");
pub const resolve = @import("resolve.zig");
pub const messaging = @import("messaging.zig");
pub const settings = @import("settings.zig");
pub const game = @import("game.zig");
pub const spawn = @import("spawn.zig");
pub const use = @import("use.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
