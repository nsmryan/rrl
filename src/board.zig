pub const blocking = @import("board/blocking.zig");
pub const fov = @import("board/fov.zig");
pub const map = @import("board/map.zig");
pub const pathing = @import("board/pathing.zig");
pub const rotate = @import("board/rotate.zig");
pub const shadowcasting = @import("board/shadowcasting.zig");
pub const tile = @import("board/tile.zig");

test "board test set" {
    _ = @import("board/blocking.zig");
    _ = @import("board/fov.zig");
    _ = @import("board/map.zig");
    _ = @import("board/pathing.zig");
    _ = @import("board/tile.zig");
    _ = @import("board/rotate.zig");
    _ = @import("board/shadowcasting.zig");
}
