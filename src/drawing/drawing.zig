pub const panel = @import("panel.zig");
pub const drawcmd = @import("drawcmd.zig");
pub const area = @import("area.zig");
pub const sprite = @import("sprite.zig");
pub const animation = @import("animation.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
