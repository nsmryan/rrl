const std = @import("std");
const print = std.debug.print;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const utils = @import("utils");
const comp = utils.comp;
const Comp = comp.Comp;

const math = @import("math");
const Pos = math.pos.Pos;
const Color = math.utils.Color;

const board = @import("board");
const Map = board.map.Map;

const core = @import("core");
const engine = @import("engine");

const g = @import("gui");
const Display = g.display.Display;
const rendering = g.rendering;

const drawcmd = @import("drawcmd");
const DrawCmd = drawcmd.drawcmd.DrawCmd;

const sdl2 = g.sdl2;

const usage_text =
    \\Usage: rustl [options] <command1> ... <commandN>
    \\
    \\Run the RustRL game
    \\
    \\Options:
    \\ -s, --seed <seed>    (default: 0) random number generator seed value
    \\
;

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    var seed: u64 = 0;

    // Parse command line arguments.
    const args = try std.process.argsAlloc(allocator);
    var arg_i: usize = 1;
    while (arg_i < args.len) : (arg_i += 1) {
        const arg = args[arg_i];
        if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--seed")) {
            arg_i += 1;
            if (arg_i >= args.len) {
                std.debug.print("'{s}' requires an additional argument.\n{s}", .{ arg, usage_text });
                std.process.exit(1);
            }
            seed = std.fmt.parseInt(u64, args[arg_i], 10) catch |err| {
                std.debug.print("unable to parse --seed argument '{s}': {s}\n", .{
                    args[arg_i], @errorName(err),
                });
                std.process.exit(1);
            };
        }
    }

    const has_profiling = @import("build_options").remotery;
    var gui = try g.Gui.init(seed, has_profiling, allocator);
    defer gui.deinit();

    try gui.game.startLevel(21, 21);
    try gui.resolveMessages();

    // Set up a splash screen.
    //gui.game.settings.state = .splash;
    //gui.game.settings.splash.set("player_standing_right"[0..]);

    var ticks = sdl2.SDL_GetTicks64();
    while (try gui.step(ticks)) {
        std.time.sleep(1000000000 / gui.game.config.frame_rate);
        ticks = sdl2.SDL_GetTicks64();
    }
}
