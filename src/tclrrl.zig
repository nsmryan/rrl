const builtin = @import("builtin");
const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const zt = @import("zigtcl");

const utils = @import("utils");
const Pos = utils.pos.Pos;

const board = @import("board");
const Map = board.map.Map;
const math = @import("math");

export fn Rrl_Init(interp: zt.Interp) c_int {
    if (builtin.os.tag != .windows) {
        _ = zt.tcl.Tcl_InitStubs(interp, "8.6", 0);
    } else {
        _ = zt.tcl.Tcl_PkgRequire(interp, "Tcl", "8.6", 0);
    }
    const namespace = "rrl";

    //_ = zt.CreateObjCommand(interp, "zigtcl::zigcreate", Hello_ZigTclCmd) catch return zt.tcl.TCL_ERROR;

    //zt.WrapFunction(test_function, "zigtcl::zig_function", interp) catch return zt.tcl.TCL_ERROR;

    _ = zt.RegisterStruct(math.pos.Pos, "Pos", namespace, interp);
    //_ = zt.RegisterStruct(Map, "Map", namespace, interp);

    //const Inner = Struct.Inner;
    //_ = zt.RegisterStruct(Inner, "Inner", "zigtcl", interp);

    return zt.tcl.Tcl_PkgProvide(interp, "rrl", "0.1.0");
}
