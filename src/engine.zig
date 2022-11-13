pub const actions = @import("engine/actions.zig");
pub const input = @import("engine/input.zig");
pub const resolve = @import("engine/resolve.zig");
pub const messaging = @import("engine/messaging.zig");
pub const settings = @import("engine/settings.zig");
pub const game = @import("engine/game.zig");
pub const spawn = @import("engine/spawn.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
