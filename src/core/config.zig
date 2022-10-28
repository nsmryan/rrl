const Config = struct {
    color_dark_brown: Color,
    color_medium_brown: Color,
    color_light_green: Color,
    color_tile_blue_light: Color,
    color_tile_blue_dark: Color,
    color_light_brown: Color,
    color_ice_blue: Color,
    color_dark_blue: Color,
    color_very_dark_blue: Color,
    color_orange: Color,
    color_red: Color,
    color_light_red: Color,
    color_medium_grey: Color,
    color_mint_green: Color,
    color_blueish_grey: Color,
    color_pink: Color,
    color_rose_red: Color,
    color_light_orange: Color,
    color_bone_white: Color,
    color_warm_grey: Color,
    color_soft_green: Color,
    color_light_grey: Color,
    color_shadow: Color,
    load_map_file_every_frame: bool,
    tile_noise_scaler: f64,
    highlight_player_move: u8,
    highlight_alpha_attack: u8,
    sound_alpha: u8,
    grid_alpha: u8,
    grid_alpha_visible: u8,
    grid_alpha_overlay: u8,
    idle_speed: f32,
    grass_idle_speed: f32,
    frame_rate: usize,
    item_throw_speed: f32,
    key_speed: f32,
    player_attack_speed: f32,
    player_attack_hammer_speed: f32,
    player_vault_sprite_speed: f32,
    player_vault_move_speed: f32,
    sound_timeout: f32,
    yell_radius: usize,
    swap_radius: usize,
    ping_sound_radius: usize,
    fog_of_war: bool,
    player_health: i32,
    player_health_max: i32,
    player_stamina: u32,
    player_stamina_max: u32,
    player_energy: u32,
    player_energy_max: u32,
    explored_alpha: u8,
    fov_edge_alpha: u8,
    sound_rubble_radius: usize,
    sound_golem_idle_radius: usize,
    sound_grass_radius: usize,
    sound_radius_crushed: usize,
    sound_radius_attack: usize,
    sound_radius_trap: usize,
    sound_radius_monster: usize,
    sound_radius_stone: usize,
    sound_radius_player: usize,
    sound_radius_hammer: usize,
    sound_radius_blunt: usize,
    sound_radius_pierce: usize,
    sound_radius_slash: usize,
    sound_radius_extra: usize,
    freeze_trap_radius: usize,
    push_stun_turns: usize,
    stun_turns_blunt: usize,
    stun_turns_pierce: usize,
    stun_turns_slash: usize,
    stun_turns_extra: usize,
    stun_turns_throw_stone: usize,
    stun_turns_throw_spear: usize,
    stun_turns_throw_default: usize,
    overlay_directions: bool,
    overlay_player_fov: bool,
    overlay_floodfill: bool,
    fov_radius_monster: i32,
    fov_radius_player: i32,
    sound_radius_sneak: usize,
    sound_radius_walk: usize,
    sound_radius_run: usize,
    dampen_blocked_tile: i32,
    dampen_short_wall: i32,
    dampen_tall_wall: i32,
    cursor_fast_move_dist: i32,
    repeat_delay: f32,
    write_map_distribution: bool,
    print_key_log: bool,
    recording: bool,
    fire_speed: f32,
    beam_duration: usize,
    draw_directional_arrow: bool,
    ghost_alpha: u8,
    particle_duration: f32,
    particle_speed: f32,
    max_particles: usize,
    attack_animation_speed: f32,
    cursor_fade_seconds: f32,
    cursor_alpha: u8,
    save_load: bool,
    minimal_output: bool,
    cursor_line: bool,
    blocking_positions: bool,
    smoke_bomb_fov_block: usize,
    smoke_turns: usize,
    looking_glass_magnify_amount: usize,
    hp_render_duration: usize,
    move_tiles_sneak: usize,
    move_tiles_walk: usize,
    move_tiles_run: usize,
    x_offset_buttons: f32,
    y_offset_buttons: f32,
    x_spacing_buttons: f32,
    y_spacing_buttons: f32,
    x_scale_buttons: f32,
    y_scale_buttons: f32,
    ui_inv_name_x_offset: f32,
    ui_inv_name_y_offset: f32,
    ui_inv_name_scale: f32,

    ui_inv_name_0_x_offset: f32,
    ui_inv_name_0_y_offset: f32,
    ui_inv_name_0_scale: f32,

    ui_inv_name_1_x_offset: f32,
    ui_inv_name_1_y_offset: f32,
    ui_inv_name_1_scale: f32,

    ui_long_name_scale: f32,

    display_console_lines: usize,

    display_center_map_on_player: bool,

    pub fn fromFile(file_name: []u8) !Config {
        var file = try std.fs.cwd().openFile(file_name, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var parts = std.mem.split(u8, line, ": ");

            const field_name = parts.next();
            const field_value = parts.next();

            const field_type_info = @typeInfo(field.field_type);
            if (field.field_type == Color) {} else if (field_type_info == .Int) {
                var colors = std.mem.split(u8, field_value, " ");
                @field(config, field.name).r = try std.fmt.parseInt(u8, field_value, 10);
                @field(config, field.name).g = try std.fmt.parseInt(u8, field_value, 10);
                @field(config, field.name).b = try std.fmt.parseInt(u8, field_value, 10);
                @field(config, field.name).a = try std.fmt.parseInt(u8, field_value, 10);
            } else if (field_type_info == .Float) {
                @field(config, field.name) = try std.fmt.parseFloat(field.field_type, field_value, 10);
            } else if (field_type_info == .Bool) {
                if (std.mem.eql(u8, field_value, "true")) {
                    @field(config, field.name) = true;
                } else if (std.mem.eql(u8, field_value, "false")) {
                    @field(config, field.name) = false;
                } else {
                    return ParseConfigError.ParseBoolError;
                }
            }
        }

        return config;
    }
};

const ParseConfigError = error{
    ParseBoolError,
};
