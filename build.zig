const std = @import("std");
const builtin = @import("builtin");
const FileSource = std.Build.FileSource;

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const step_options = b.addOptions();
    step_options.addOption(bool, "remotery", false);

    buildMain(b, target, mode, step_options);
    buildTests(b, target, mode, step_options);
    buildTclExtension(b, target, mode, step_options);
    try runAtlas(b, target, mode);
}

// Main Executable
fn buildMain(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, step_options: *std.build.OptionsStep) void {
    _ = step_options;
    const exe = b.addExecutable(.{ .name = "rustrl", .root_source_file = FileSource.relative("main.zig") });

    exe.target = target;
    exe.optimize = mode;

    const options = b.addOptions();
    // TODO set to false when build options are working...
    options.addOption(bool, "remotery", true);
    exe.addOptions("build_options", options);

    exe.addIncludePath("deps/remotery");
    exe.addCSourceFile("deps/remotery/Remotery.c", &[_][]const u8{
        "-DRMT_ENABLED=1",
    });

    addPackages(exe);
    addCDeps(exe);
    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const rustrl_step = b.step("rustrl", "Build the zig version of the game");
    rustrl_step.dependOn(&exe.step);

    const run_step = b.step("run", "Run the zig version of the game");
    run_step.dependOn(&run_cmd.step);
}

// Unit tests
fn buildTests(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, step_options: *std.build.OptionsStep) void {
    _ = step_options;
    const exe_tests = b.addTest(.{ .name = "main tests", .root_source_file = FileSource.relative("main_test.zig") });
    exe_tests.target = target;
    exe_tests.optimize = mode;

    const options = b.addOptions();
    options.addOption(bool, "remotery", false);
    exe_tests.addOptions("build_options", options);

    exe_tests.addIncludePath("deps/remotery");
    exe_tests.addCSourceFile("deps/remotery/Remotery.c", &[_][]const u8{
        "-DRMT_ENABLED=1",
    });

    addPackages(exe_tests);
    addCDeps(exe_tests);
    exe_tests.linkLibC();

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

// Shared Library TCL Extension
fn buildTclExtension(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, step_options: *std.build.OptionsStep) void {
    _ = step_options;
    const lib = b.addSharedLibrary(
        .{ .name = "rrl", .root_source_file = FileSource.relative("tclrrl.zig"), .target = target, .optimize = mode },
    );
    lib.linkLibC();

    const options = b.addOptions();
    options.addOption(bool, "remotery", false);
    lib.addOptions("build_options", options);

    lib.addIncludePath("deps/remotery");
    lib.addCSourceFile("deps/remotery/Remotery.c", &[_][]const u8{
        "-DRMT_ENABLED=1",
    });

    if (builtin.os.tag == .windows) {
        lib.addLibPath("c:/tcltk/bin");
        lib.addLibPath("c:/tcltk/lib");
        lib.addIncludePath("c:/tcltk/include");
        lib.linkSystemLibraryName("tcl86");
    } else {
        lib.addIncludePath("deps/tcl/include");
        lib.addObjectFile("deps/tcl/lib/libtclstub8.6.a");
    }

    lib.addPackagePath("zigtcl", "deps/zig_tcl/zigtcl.zig");
    addPackages(lib);
    addCDeps(lib);

    b.installArtifact(lib);

    const lib_step = b.step("tcl", "Build TCL extension");
    lib_step.dependOn(&lib.step);
}

// Run Atlas Process
fn runAtlas(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode) !void {
    const exe = b.addExecutable(.{ .name = "atlas" });
    exe.target = target;
    exe.optimize = mode;
    exe.linkLibC();

    // C source
    exe.addCSourceFile("deps/atlas/main.c", &[_][]const u8{});
    exe.addCSourceFile("deps/atlas/bitmap.c", &[_][]const u8{});
    exe.addCSourceFile("deps/atlas/util.c", &[_][]const u8{});
    exe.addCSourceFile("deps/atlas/lib/stb/stb_image.c", &[_][]const u8{});
    exe.addCSourceFile("deps/atlas/lib/stb/stb_image_write.c", &[_][]const u8{});
    exe.addCSourceFile("deps/atlas/lib/stb/stb_rect_pack.c", &[_][]const u8{});
    exe.addCSourceFile("deps/atlas/lib/stb/stb_truetype.c", &[_][]const u8{});

    // C include paths
    exe.addIncludePath("deps/atlas");
    exe.addIncludePath("deps/atlas/lib/stb");

    b.installArtifact(exe);

    const run_cmd = exe.addRunArtifact();
    run_cmd.step.dependOn(b.getInstallStep());
    var dir = try std.fs.cwd().openIterableDir("data/sprites/animations/", .{});
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind == .Directory) {
            const path = try std.mem.join(b.allocator, "/", &[_][]const u8{ "data/sprites/animations", entry.path });
            defer b.allocator.free(path);
            run_cmd.addArg(path);
        }
    }
    run_cmd.addArg("data/sprites/misc/"[0..]);
    run_cmd.addArg("data/sprites/UI/"[0..]);
    run_cmd.addArg("data/sprites/tileset/"[0..]);

    run_cmd.addArg("--imageout"[0..]);
    run_cmd.addArg("data/spriteAtlas.png"[0..]);
    run_cmd.addArg("--textout"[0..]);
    run_cmd.addArg("data/spriteAtlas.txt"[0..]);

    const tileset_cmd = b.addSystemCommand(&[_][]const u8{"tclsh"});
    tileset_cmd.addArg("scripts/add_tiles_to_atlas.tcl"[0..]);
    tileset_cmd.addArg("data/spriteAtlas.txt"[0..]);
    tileset_cmd.addArg("data/tile_locations.txt"[0..]);
    tileset_cmd.step.dependOn(&run_cmd.step);

    const run_step = b.step("atlas", "Run the atlas creation process");
    run_step.dependOn(&tileset_cmd.step);
}

const pkgs = struct {
    const utils = std.build.Pkg{
        .name = "utils",
        .source = .{ .path = "src/utils/utils.zig" },
        .dependencies = &[_]std.build.Pkg{},
    };

    const prof = std.build.Pkg{
        .name = "prof",
        .source = .{ .path = "src/prof.zig" },
        .dependencies = &[_]std.build.Pkg{},
    };

    const math = std.build.Pkg{
        .name = "math",
        .source = .{ .path = "src/math/math.zig" },
        .dependencies = &[_]std.build.Pkg{},
    };

    const core = std.build.Pkg{
        .name = "core",
        .source = .{ .path = "src/core/core.zig" },
        .dependencies = &[_]std.build.Pkg{ utils, math, board, prof },
    };

    const drawing = std.build.Pkg{
        .name = "drawing",
        .source = .{ .path = "src/drawing/drawing.zig" },
        .dependencies = &[_]std.build.Pkg{ math, utils },
    };

    const board = std.build.Pkg{
        .name = "board",
        .source = .{ .path = "src/board/board.zig" },
        .dependencies = &[_]std.build.Pkg{ math, prof, utils },
    };

    const engine = std.build.Pkg{
        .name = "engine",
        .source = .{ .path = "src/engine/engine.zig" },
        .dependencies = &[_]std.build.Pkg{ core, math, utils, board, prof },
    };

    const gui = std.build.Pkg{
        .name = "gui",
        .source = .{ .path = "src/gui/gui.zig" },
        .dependencies = &[_]std.build.Pkg{ core, math, drawing, utils, board, engine, prof },
    };
};

fn addPackages(step: *std.build.LibExeObjStep) void {
    step.addPackage(pkgs.board);
    step.addPackage(pkgs.utils);
    step.addPackage(pkgs.core);
    step.addPackage(pkgs.drawing);
    step.addPackage(pkgs.math);
    step.addPackage(pkgs.gui);
    step.addPackage(pkgs.engine);
    step.addPackage(pkgs.prof);
}

fn addCDeps(step: *std.build.LibExeObjStep) void {
    // Add SDL2 dependency
    step.addIncludePath("deps/SDL2/include");
    step.linkSystemLibrary("SDL2");
    step.linkSystemLibrary("SDL2_ttf");
    step.linkSystemLibrary("SDL2_image");
}
