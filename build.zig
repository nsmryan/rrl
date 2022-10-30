const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});

    const mode = b.standardReleaseOptions();

    // Main Executable
    const exe = b.addExecutable("rustrl", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    addPackages(exe);
    exe.linkLibC();
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    addPackages(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    // Shared Library TCL Extension
    const lib = b.addSharedLibrary("rrl", "src/tclrrl.zig", b.version(0, 1, 0));
    lib.setBuildMode(mode);
    lib.linkLibC();

    if (builtin.os.tag == .windows) {
        lib.addLibPath("c:/tcltk/bin");
        lib.addLibPath("c:/tcltk/lib");
        lib.addIncludePath("c:/tcltk/include");
        lib.linkSystemLibraryName("tcl86");
    } else {
        lib.addIncludePath("deps/tcl/include");
        lib.addObjectFile("deps/tcl/lib/libtclstub8.6.a");
    }

    // Add packages
    lib.addPackagePath("zigtcl", "deps/zig_tcl/zigtcl.zig");
    addPackages(lib);

    lib.install();

    const lib_step = b.step("tcl", "Build TCL extension");
    lib_step.dependOn(&lib.step);
}

const pkgs = struct {
    const utils = std.build.Pkg{
        .name = "utils",
        .source = .{ .path = "src/utils.zig" },
        .dependencies = &[_]std.build.Pkg{},
    };

    const math = std.build.Pkg{
        .name = "math",
        .source = .{ .path = "src/math.zig" },
        .dependencies = &[_]std.build.Pkg{},
    };

    const core = std.build.Pkg{
        .name = "core",
        .source = .{ .path = "src/core.zig" },
        .dependencies = &[_]std.build.Pkg{ utils, math, board },
    };

    const drawcmd = std.build.Pkg{
        .name = "drawcmd",
        .source = .{ .path = "src/drawcmd.zig" },
        .dependencies = &[_]std.build.Pkg{math},
    };

    const board = std.build.Pkg{
        .name = "board",
        .source = .{ .path = "src/board.zig" },
        .dependencies = &[_]std.build.Pkg{math},
    };

    const events = std.build.Pkg{
        .name = "events",
        .source = .{ .path = "src/events.zig" },
        .dependencies = &[_]std.build.Pkg{ math, core, gen },
    };

    const gui = std.build.Pkg{
        .name = "gui",
        .source = .{ .path = "src/gui.zig" },
        .dependencies = &[_]std.build.Pkg{ core, math, drawcmd, utils, events, board, gen },
    };

    const gen = std.build.Pkg{
        .name = "gen",
        .source = .{ .path = "src/gen.zig" },
        .dependencies = &[_]std.build.Pkg{ math, utils },
    };
};

fn addPackages(step: *std.build.LibExeObjStep) void {
    step.addPackage(pkgs.board);
    step.addPackage(pkgs.utils);
    step.addPackage(pkgs.core);
    step.addPackage(pkgs.drawcmd);
    step.addPackage(pkgs.math);
    step.addPackage(pkgs.events);
    step.addPackage(pkgs.gui);

    // Add SDL2 dependency
    step.addIncludePath("deps/SDL2/include");
    step.linkSystemLibrary("SDL2");
    step.linkSystemLibrary("SDL2_ttf");
    step.linkSystemLibrary("SDL2_image");
}
