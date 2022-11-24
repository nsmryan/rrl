const std = @import("std");

pub const rmt = @cImport({
    @cInclude("Remotery.pp.h");
});

pub const ProfilerError = error{
    RemoteryError,
};

pub const Prof = struct {
    remotery: ?*rmt.Remotery = undefined,
    running: bool = false,
    err: c_uint = 0,

    pub fn start(prof: *Prof) ProfilerError!void {
        const err = rmt._rmt_CreateGlobalInstance(&prof.remotery);
        if (err != 0) {
            prof.err = err;
            return ProfilerError.RemoteryError;
        } else {
            prof.running = true;
        }
    }

    pub fn end(prof: *Prof) void {
        if (prof.running) {
            _ = rmt._rmt_DestroyGlobalInstance(prof.remotery);
        }
    }
};

pub fn log(text: [*c]const u8) void {
    rmt._rmt_LogText(text);
}

pub fn scope(name: [*c]const u8) void {
    rmt._rmt_BeginCPUSample(name, 0, null);
}

pub fn end() void {
    rmt._rmt_EndCPUSample();
}
