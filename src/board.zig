pub const blocking = @import("board/blocking.zig");
pub const fov = @import("board/fov.zig");
pub const map = @import("board/map.zig");
pub const pathing = @import("board/pathing.zig");
pub const rotate = @import("board/rotate.zig");
pub const shadowcasting = @import("board/shadowcasting.zig");
pub const tile = @import("board/tile.zig");

comptime {
    if (@import("builtin").is_test) {
        @import("std").testing.refAllDecls(@This());
    }
}
