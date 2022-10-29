const std = @import("std");
const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

const g = @import("game.zig");
const Game = g.Game;

const math = @import("math");
const Pos = math.pos.Pos;
const Direction = math.direction.Direction;

const core = @import("core");
const movement = core.movement;
const Config = core.config.Config;

const gen = @import("gen");

const events = @import("events");
const Input = events.input.Input;
const UseAction = events.actions.UseAction;

pub const display = @import("gui/display.zig");
pub const input = @import("gui/keyboard.zig");
pub const drawing = @import("gui/drawing.zig");
pub const sdl2 = @import("gui/sdl2.zig");

pub const Gui = struct {
    display: display.Display,
    input: Input,
    config: Config,
    settings: Settings,
    game: Game,

    pub fn init(seed: u64, allocator: Allocator) !Gui {
        var rng = RndGen.init(seed);
        return Gui{
            .display = try display.Display.init(800, 640),
            .input = Input.init(allocator),
            .game = Game.init(rng.random(), allocator),
            .config = try Config.fromFile("config.txt"[0..]),
            .settings = Settings.init(),
        };
    }

    pub fn step(game: *Game) void {
        // Poll for sdl2 events.
        // translateEvent input into InputAction (maybe rename Action)
        // dispatch based on state and turn InputAction into messages
        // Messages must be implemented, and include a "now" concept to simplfy use code.
        // Add a resolve function which then modifies the game based on the messages.
        //
        const ticks = sdl2.SDL2_GetTicks64;
        var event: sdl2.SDL_Event = undefined;
        while (sdl2.SDL_PollEvent(&event) != 0) {
            if (events.input.translateEvent(event)) |input_event| {
                const input_action = game.input.handleEvent(input_event, &game.settings, ticks, &game.config);
                _ = input_action;
            }
        }
    }
};

pub const LevelExitCondition = enum {
    rightEdge,
    keyAndGoal,
};

pub const Settings = struct {
    turn_count: usize,
    test_mode: bool,
    map_type: gen.make_map.MapGenType,
    state: g.GameState,
    overlay: bool,
    level_num: usize,
    running: bool,
    cursor: ?Pos,
    use_action: UseAction,
    cursor_action: ?UseAction,
    use_dir: ?Direction,
    move_mode: movement.MoveMode,
    debug_enabled: bool,
    map_load_config: gen.make_map.MapLoadConfig,
    map_changed: bool,
    exit_condition: LevelExitCondition,

    pub fn init() Settings {
        return Settings{
            .turn_count = 0,
            .test_mode = false,
            .map_type = gen.make_map.MapGenType.island,
            .state = g.GameState.playing,
            .overlay = false,
            .level_num = 0,
            .running = true,
            .cursor = null,
            .use_action = UseAction.interact,
            .cursor_action = null,
            .use_dir = null,
            .move_mode = movement.MoveMode.walk,
            .debug_enabled = false,
            .map_load_config = gen.make_map.MapLoadConfig.empty,
            .map_changed = false,
            .exit_condition = LevelExitCondition.rightEdge,
        };
    }

    pub fn isCursorMode(self: *Settings) bool {
        return self.cursor != null;
    }
};

test "gui test set" {
    _ = @import("gui/display.zig");
    _ = @import("gui/keyboard.zig");
    _ = @import("gui/drawing.zig");
    _ = @import("gui/sdl2.zig");
}
