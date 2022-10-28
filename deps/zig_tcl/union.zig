const std = @import("std");

const testing = std.testing;

const err = @import("err.zig");
const obj = @import("obj.zig");
const call = @import("call.zig");
const utils = @import("utils.zig");
const tcl = @import("tcl.zig");

pub const UnionCmds = enum {
    create,
    call,
    variants,
    fromBytes,
    size,
    with,
};

pub const UnionInstanceCmds = enum {
    value,
    variant,
    call,
    bytes,
    setBytes,
    ptr,
};

pub fn RegisterUnion(comptime unn: type, comptime name: []const u8, comptime pkg: []const u8, interp: obj.Interp) c_int {
    if (@typeInfo(unn) != .Union) {
        @compileError("Attempting to register a non-union as a union!");
    }

    if (@typeInfo(unn).Union.tag_type == null) {
        @compileError("Registered unions must have a tag type! Untagged unions are not supported");
    }

    const terminator: [1]u8 = .{0};
    const cmdName = pkg ++ "::" ++ name ++ terminator;
    _ = obj.CreateObjCommand(interp, cmdName, UnionCommand(unn).command) catch |errResult| return err.ErrorToInt(errResult);

    return tcl.TCL_OK;
}

pub fn UnionCommand(comptime unn: type) type {
    return struct {
        pub fn command(cdata: tcl.ClientData, interp: [*c]tcl.Tcl_Interp, objv: []const obj.Obj) err.TclError!void {
            _ = cdata;

            switch (try obj.GetIndexFromObj(UnionCmds, interp, objv[1], "commands")) {
                .create => {
                    if (objv.len < 3) {
                        tcl.Tcl_WrongNumArgs(interp, @intCast(c_int, objv.len), objv.ptr, "create name");
                        return err.TclError.TCL_ERROR;
                    }

                    const name = try obj.GetStringFromObj(objv[2]);

                    var ptr = tcl.Tcl_Alloc(@sizeOf(unn));
                    const result = tcl.Tcl_CreateObjCommand(interp, name.ptr, UnionInstanceCommand, @ptrCast(tcl.ClientData, ptr), utils.TclDeallocateCallback);
                    if (result == null) {
                        obj.SetStrResult(interp, "Could not create command!");
                        return err.TclError.TCL_ERROR;
                    } else {
                        return;
                    }
                },

                .call => {
                    if (objv.len < 3) {
                        tcl.Tcl_WrongNumArgs(interp, @intCast(c_int, objv.len), objv.ptr, "call decl");
                        return err.TclError.TCL_ERROR;
                    }

                    const name = try obj.GetStringFromObj(objv[2]);

                    // Search for a decl of the given name.
                    comptime var decls = std.meta.declarations(unn);
                    inline for (decls) |decl| {
                        // Ignore privatve decls
                        if (!decl.is_pub) {
                            continue;
                        }

                        const field = @field(unn, decl.name);
                        const field_info = call.FuncInfo(@typeInfo(@TypeOf(field))) orelse continue;

                        comptime {
                            if (!utils.CallableFunction(field_info)) {
                                continue;
                            }
                        }

                        // If the name matches attempt to call it.
                        if (std.mem.eql(u8, name, decl.name)) {
                            try call.CallDecl(field, interp, @intCast(c_int, objv.len), objv.ptr);
                            return;
                        }
                    }

                    obj.SetStrResult(interp, "One or more field names not found in union call!");
                    return err.TclError.TCL_ERROR;
                },

                .variants => {
                    comptime var fields = std.meta.fields(unn);
                    var resultList = obj.NewListObj(&.{});
                    inline for (fields) |field| {
                        try obj.ListObjAppendElement(interp, resultList, obj.NewStringObj(field.name));
                        try obj.ListObjAppendElement(interp, resultList, obj.NewStringObj(@typeName(field.field_type)));
                    }

                    obj.SetObjResult(interp, resultList);
                    return;
                },

                .fromBytes => {
                    if (objv.len < 4) {
                        tcl.Tcl_WrongNumArgs(interp, @intCast(c_int, objv.len), objv.ptr, "fromBytes name bytes");
                        return err.TclError.TCL_ERROR;
                    }

                    const name = try obj.GetStringFromObj(objv[2]);

                    var length: c_int = undefined;
                    var bytes = tcl.Tcl_GetByteArrayFromObj(objv[3], &length);

                    if (length != @sizeOf(unn)) {
                        obj.SetStrResult(interp, "Byte array size does not match union!");
                        return err.TclError.TCL_ERROR;
                    }

                    var ptr = tcl.Tcl_Alloc(@sizeOf(unn));
                    @memcpy(ptr, bytes, @sizeOf(unn));

                    const result = tcl.Tcl_CreateObjCommand(interp, name.ptr, UnionInstanceCommand, @ptrCast(tcl.ClientData, ptr), utils.TclDeallocateCallback);
                    if (result == null) {
                        obj.SetStrResult(interp, "Could not create command!");
                        return err.TclError.TCL_ERROR;
                    } else {
                        return;
                    }
                },

                .size => {
                    obj.SetObjResult(interp, try obj.ToObj(@intCast(c_int, @sizeOf(unn))));
                    return;
                },

                .with => {
                    if (objv.len < 4) {
                        tcl.Tcl_WrongNumArgs(interp, @intCast(c_int, objv.len), objv.ptr, "with pointer decl args...");
                        return err.TclError.TCL_ERROR;
                    }
                    const ptr = try obj.GetFromObj(*unn, interp, objv[2]);
                    const objc = @intCast(c_int, objv.len - 2);
                    var objv_subset = objv[2..].ptr;
                    var clientData = @ptrCast(tcl.ClientData, ptr);
                    try err.HandleReturn(UnionInstanceCommand(clientData, interp, objc, objv_subset));
                    return;
                },
            }

            obj.SetStrResult(interp, "Unexpected subcommand name on union type!");
            return err.TclError.TCL_ERROR;
        }

        fn UnionInstanceCommand(cdata: tcl.ClientData, interp: [*c]tcl.Tcl_Interp, objc: c_int, objv: [*c]const [*c]tcl.Tcl_Obj) callconv(.C) c_int {
            _ = cdata;
            // support the cget, field, call, configure interface in syntax.tcl
            if (objc < 2) {
                tcl.Tcl_WrongNumArgs(interp, objc, objv, "field name [value]");
                return tcl.TCL_ERROR;
            }

            var ptr = @ptrCast(*unn, @alignCast(@alignOf(unn), cdata));
            const cmd = obj.GetIndexFromObj(UnionInstanceCmds, interp, objv[1], "commands") catch |errResult| return err.TclResult(errResult);
            switch (cmd) {
                .value => {
                    return err.TclResult(UnionValueFieldCmd(ptr, interp, obj.ObjSlice(objc, objv)));
                },

                .variant => {
                    return err.TclResult(UnionVariantFieldCmd(ptr, interp, obj.ObjSlice(objc, objv)));
                },

                .call => {
                    return err.TclResult(UnionCallCmd(ptr, interp, obj.ObjSlice(objc, objv)));
                },

                .bytes => {
                    return err.TclResult(UnionBytesCmd(ptr, interp, obj.ObjSlice(objc, objv)));
                },

                .setBytes => {
                    return err.TclResult(UnionSetBytesCmd(ptr, interp, obj.ObjSlice(objc, objv)));
                },

                .ptr => {
                    return err.TclResult(UnionPtrCmd(ptr, interp, obj.ObjSlice(objc, objv)));
                },
            }
            obj.SetStrResult(interp, "Unexpected subcommand!");
            return tcl.TCL_ERROR;
        }

        pub fn UnionValueFieldCmd(ptr: *unn, interp: obj.Interp, objv: []const obj.Obj) err.TclError!void {
            if (objv.len < 2) {
                obj.WrongNumArgs(interp, objv, "value");
                return err.TclError.TCL_ERROR;
            }

            const variantName = @tagName(ptr.*);
            comptime var fields = std.meta.fields(unn);
            inline for (fields) |field| {
                if (std.mem.eql(u8, variantName, field.name)) {
                    var fieldObj = try obj.ToObj(@field(ptr.*, field.name));
                    obj.SetObjResult(interp, fieldObj);
                    return;
                }
            }

            obj.SetStrResult(interp, "Variant name not found in union!");
            return err.TclError.TCL_ERROR;
        }

        pub fn UnionVariantFieldCmd(ptr: *unn, interp: obj.Interp, objv: []const obj.Obj) err.TclError!void {
            if (objv.len < 4) {
                obj.WrongNumArgs(interp, objv, "variant name value");
                return err.TclError.TCL_ERROR;
            }

            const name = try obj.GetStringFromObj(objv[2]);

            comptime var fields = std.meta.fields(unn);
            inline for (fields) |field| {
                if (std.mem.eql(u8, name, field.name)) {
                    if (objv.len > 4) {
                        if (@typeInfo(field.field_type) != .Struct) {
                            obj.SetStrResult(interp, "Multiple argument variants only work on anonomous structs!");
                            return err.TclError.TCL_ERROR;
                        }
                        var args: field.field_type = undefined;

                        var obj_index: usize = 3;
                        comptime var chosen_fields = std.meta.fields(field.field_type);
                        inline for (chosen_fields) |chosen_field| {
                            @field(args, chosen_field.name) = try obj.GetFromObj(chosen_field.field_type, interp, objv[obj_index]);
                            obj_index += 1;
                        }
                        ptr.* = @unionInit(unn, field.name, args);
                    } else {
                        ptr.* = @unionInit(unn, field.name, try obj.GetFromObj(field.field_type, interp, objv[3]));
                    }
                    return;
                }
            }

            obj.SetStrResult(interp, "Variant name not found in union!");
            return err.TclError.TCL_ERROR;
        }

        pub fn UnionCallCmd(ptr: *unn, interp: obj.Interp, objv: []const obj.Obj) err.TclError!void {
            if (objv.len < 3) {
                obj.WrongNumArgs(interp, objv, "call name [args]");
                return err.TclError.TCL_ERROR;
            }

            const name = try obj.GetStringFromObj(objv[2]);

            // Search for a decl of the given name.
            comptime var decls = std.meta.declarations(unn);
            inline for (decls) |decl| {
                // Ignore privatve decls
                if (!decl.is_pub) {
                    continue;
                }

                const field = @field(unn, decl.name);
                const field_info = call.FuncInfo(@typeInfo(@TypeOf(field))) orelse continue;

                comptime {
                    if (!utils.CallableDecl(unn, field_info)) {
                        continue;
                    }
                }

                // If the name matches attempt to call it.
                if (std.mem.eql(u8, name, decl.name)) {
                    try call.CallBound(field, interp, @ptrCast(tcl.ClientData, ptr), @intCast(c_int, objv.len), objv.ptr);

                    return;
                }
            }

            obj.SetStrResult(interp, "One or more field names not found in union call!");
            return err.TclError.TCL_ERROR;
        }

        pub fn UnionBytesCmd(ptr: *unn, interp: obj.Interp, objv: []const obj.Obj) err.TclError!void {
            _ = objv;
            obj.SetObjResult(interp, try obj.ToObj(ptr.*));
        }

        pub fn UnionSetBytesCmd(ptr: *unn, interp: obj.Interp, objv: []const obj.Obj) err.TclError!void {
            if (objv.len < 3) {
                obj.WrongNumArgs(interp, objv, "fromBytes bytes");
                return err.TclError.TCL_ERROR;
            }

            var length: c_int = undefined;
            var bytes = tcl.Tcl_GetByteArrayFromObj(objv[2], &length);
            if (length == @sizeOf(unn)) {
                @memcpy(@ptrCast([*]u8, ptr), bytes, @intCast(usize, length));
                return;
            } else {
                obj.SetStrResult(interp, "Byte array size does not match union!");
                return err.TclError.TCL_ERROR;
            }
        }

        pub fn UnionPtrCmd(ptr: *unn, interp: obj.Interp, objv: []const obj.Obj) err.TclError!void {
            if (objv.len == 2) {
                obj.SetObjResult(interp, try obj.ToObj(ptr));
            } else {
                tcl.Tcl_WrongNumArgs(interp, @intCast(c_int, objv.len), objv.ptr, "ptr");
            }
        }
    };
}

test "unn create/variant/value" {
    const u = union(enum) {
        v0: u32,
        v1: [4]u8,
        v2: f64,
    };
    var interp = tcl.Tcl_CreateInterp();
    defer tcl.Tcl_DeleteInterp(interp);

    var result: c_int = undefined;
    result = RegisterUnion(u, "u", "test", interp);
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "test::u create instance");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    {
        result = tcl.Tcl_Eval(interp, "instance variant v0 100");
        try std.testing.expectEqual(tcl.TCL_OK, result);

        result = tcl.Tcl_Eval(interp, "instance value");
        try std.testing.expectEqual(tcl.TCL_OK, result);
        const resultObj = tcl.Tcl_GetObjResult(interp);
        try std.testing.expectEqual(@as(u32, 100), try obj.GetFromObj(u32, interp, resultObj));
    }

    {
        result = tcl.Tcl_Eval(interp, "instance variant v1 test");
        try std.testing.expectEqual(tcl.TCL_OK, result);

        result = tcl.Tcl_Eval(interp, "instance value");
        try std.testing.expectEqual(tcl.TCL_OK, result);
        const resultObj = tcl.Tcl_GetObjResult(interp);
        const expected: [4]u8 = .{ 't', 'e', 's', 't' };
        try std.testing.expectEqual(expected, try obj.GetFromObj([4]u8, interp, resultObj));
    }

    {
        result = tcl.Tcl_Eval(interp, "instance variant v2 1.4");
        try std.testing.expectEqual(tcl.TCL_OK, result);

        result = tcl.Tcl_Eval(interp, "instance value");
        try std.testing.expectEqual(tcl.TCL_OK, result);
        const resultObj = tcl.Tcl_GetObjResult(interp);
        try std.testing.expectEqual(@as(f64, 1.4), try obj.GetFromObj(f64, interp, resultObj));
    }
}

test "unn anonomous struct variant" {
    const u = union(enum) {
        v0: struct { field0: u32, field1: u8 },
    };
    var interp = tcl.Tcl_CreateInterp();
    defer tcl.Tcl_DeleteInterp(interp);

    var unn: u = .{ .v0 = .{ .field0 = 101, .field1 = 202 } };

    var result: c_int = undefined;
    result = RegisterUnion(u, "u", "test", interp);
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "test::u create instance");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "instance variant v0 101 202");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "instance ptr");
    try std.testing.expectEqual(tcl.TCL_OK, result);
    const resultObj = tcl.Tcl_GetObjResult(interp);

    var unn_ptr = try obj.GetFromObj(*u, interp, resultObj);
    try std.testing.expectEqual(unn.v0.field0, unn_ptr.v0.field0);
    try std.testing.expectEqual(unn.v0.field1, unn_ptr.v0.field1);
}

test "unn create/call" {
    const u = union(enum) {
        v0: u32,

        pub fn decl1(self: *@This(), newFieldValue: u32) u32 {
            const old: u32 = self.v0;
            self.* = .{ .v0 = newFieldValue };
            return old;
        }

        pub fn decl2(self: @This()) u32 {
            return self.v0;
        }
    };
    var interp = tcl.Tcl_CreateInterp();
    defer tcl.Tcl_DeleteInterp(interp);

    var result: c_int = undefined;
    result = RegisterUnion(u, "u", "test", interp);
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "test::u create instance");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "instance variant v0 99");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    var cmd_info: tcl.Tcl_CmdInfo = undefined;
    _ = tcl.Tcl_GetCommandInfo(interp, "instance", &cmd_info);

    {
        result = tcl.Tcl_Eval(interp, "instance call decl1 200");
        try std.testing.expectEqual(tcl.TCL_OK, result);
        const resultObj = tcl.Tcl_GetObjResult(interp);
        try std.testing.expectEqual(@as(u32, 99), try obj.GetFromObj(u32, interp, resultObj));
    }

    {
        result = tcl.Tcl_Eval(interp, "instance value");
        try std.testing.expectEqual(tcl.TCL_OK, result);
        const resultObj = tcl.Tcl_GetObjResult(interp);
        try std.testing.expectEqual(@as(u32, 200), try obj.GetFromObj(u32, interp, resultObj));
    }

    {
        result = tcl.Tcl_Eval(interp, "instance call decl2");
        try std.testing.expectEqual(tcl.TCL_OK, result);
        const resultObj = tcl.Tcl_GetObjResult(interp);
        try std.testing.expectEqual(@as(u32, 200), try obj.GetFromObj(u32, interp, resultObj));
    }
}

test "unn type call decl" {
    const u = union(enum) {
        v0: u8,

        pub fn decl1(value: u32) u32 {
            return value + 10;
        }
    };
    var interp = tcl.Tcl_CreateInterp();
    defer tcl.Tcl_DeleteInterp(interp);

    var result: c_int = undefined;
    result = RegisterUnion(u, "u", "test", interp);
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "test::u call decl1 1");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    const resultObj = tcl.Tcl_GetObjResult(interp);
    try std.testing.expectEqual(@as(u32, 11), try obj.GetFromObj(u32, interp, resultObj));
}

test "unn bytes" {
    const u = union(enum) {
        v0: u8,
        v1: f64,
    };
    var interp = tcl.Tcl_CreateInterp();
    defer tcl.Tcl_DeleteInterp(interp);

    var result: c_int = undefined;
    result = RegisterUnion(u, "u", "test", interp);
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "test::u create instance");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "instance variant v1 10.0");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "instance bytes");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    var byteObj = tcl.Tcl_GetObjResult(interp);

    var length: c_int = undefined;
    var bytes = tcl.Tcl_GetByteArrayFromObj(byteObj, &length);

    var cmdInfo: tcl.Tcl_CmdInfo = undefined;
    _ = tcl.Tcl_GetCommandInfo(interp, "instance", &cmdInfo);

    try std.testing.expectEqualSlices(u8, bytes[0..@intCast(usize, length)], @ptrCast([*]u8, cmdInfo.objClientData)[0..@sizeOf(u)]);

    result = tcl.Tcl_Eval(interp, "test::u fromBytes instance2 [instance bytes]");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "instance2 value");
    try std.testing.expectEqual(tcl.TCL_OK, result);
    const resultObj = tcl.Tcl_GetObjResult(interp);
    try std.testing.expectEqual(@as(f64, 10.0), try obj.GetFromObj(f64, interp, resultObj));
}

test "union ptr" {
    const u = union(enum) {
        field0: u64,
        field1: u64,
    };
    var interp = tcl.Tcl_CreateInterp();
    defer tcl.Tcl_DeleteInterp(interp);

    var result: c_int = undefined;
    result = RegisterUnion(u, "u", "test", interp);
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "test::u create instance");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "instance variant field0 101");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "instance ptr");
    try std.testing.expectEqual(tcl.TCL_OK, result);
    var u_ptr = try obj.GetFromObj(*u, interp, tcl.Tcl_GetObjResult(interp));

    try std.testing.expectEqual(@as(u64, 101), u_ptr.field0);
}

test "union size" {
    const u = union(enum) {
        field0: u8,
        field1: f64,
    };
    var interp = tcl.Tcl_CreateInterp();
    defer tcl.Tcl_DeleteInterp(interp);

    var result: c_int = undefined;
    result = RegisterUnion(u, "u", "test", interp);
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "test::u size");
    try std.testing.expectEqual(tcl.TCL_OK, result);
    const resultObj = tcl.Tcl_GetObjResult(interp);
    try std.testing.expectEqual(@as(u32, @sizeOf(u)), try obj.GetFromObj(u32, interp, resultObj));
}

test "union with" {
    const u = union(enum) {
        field0: f64,
        field1: u32,
    };
    var interp = tcl.Tcl_CreateInterp();
    defer tcl.Tcl_DeleteInterp(interp);

    var result: c_int = undefined;
    result = RegisterUnion(u, "u", "test", interp);
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "test::u create instance");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "test::u with [instance ptr] variant field1 101");
    try std.testing.expectEqual(tcl.TCL_OK, result);

    result = tcl.Tcl_Eval(interp, "instance value field1");
    try std.testing.expectEqual(tcl.TCL_OK, result);
    const resultObj = tcl.Tcl_GetObjResult(interp);
    try std.testing.expectEqual(@as(u32, 101), try obj.GetFromObj(u32, interp, resultObj));
}
