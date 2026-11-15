const std = @import("std");

const hook_module = @import("system/hook.zig");
const win32 = @import("system/win32.zig");

const Hook = hook_module.Hook;

fn ignore(
    _: ?win32.HWINEVENTHOOK,
    _: u32,
    _: ?win32.HWND,
    _: i32,
    _: i32,
    _: u32,
    _: u32,
) callconv(.winapi) void {}

const testing = std.testing;

test "a hook installs, stops its thread, and installs again" {
    const hook = try testing.allocator.create(Hook);
    defer testing.allocator.destroy(hook);

    for (0..2) |_| {
        hook.init(ignore);

        try testing.expect(hook.is_installed());

        hook.deinit();
    }
}
