const std = @import("std");
const dvui = @import("dvui");

const App = @import("app.zig");
const win32 = @import("system/win32.zig");

const assert = std.debug.assert;

var instance: std.atomic.Value(?*App) = .init(null);

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 1000.0, .h = 700.0 },
            .min_size = .{ .w = 400.0, .h = 300.0 },
            .org = "braycarlson",
            .app = "prototype",
            .title = "Prototype UI",
        },
    },
    .initFn = app_init,
    .deinitFn = app_deinit,
    .frameFn = app_frame,
};

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn };

fn app_init(window: *dvui.Window) !void {
    const app = try window.gpa.create(App);
    errdefer window.gpa.destroy(app);

    if (instance.cmpxchgStrong(null, app, .seq_cst, .seq_cst) != null) return error.AppRunning;

    app.init(hook_procedure);
    window.themeSet(dvui.Theme.builtin.adwaita_dark);

    assert(instance.load(.seq_cst) == app);
}

fn app_deinit(window: *dvui.Window) void {
    const app = instance.load(.seq_cst) orelse unreachable;

    app.deinit();
    instance.store(null, .seq_cst);
    window.gpa.destroy(app);

    assert(instance.load(.seq_cst) == null);
}

fn app_frame() !dvui.App.Result {
    const app = instance.load(.seq_cst) orelse unreachable;

    app.frame();

    return .ok;
}

fn hook_procedure(
    _: ?win32.HWINEVENTHOOK,
    event: u32,
    hwnd: ?win32.HWND,
    id_object: i32,
    _: i32,
    _: u32,
    _: u32,
) callconv(.winapi) void {
    const app = instance.load(.seq_cst) orelse unreachable;

    assert(app.hook.thread_id == std.Thread.getCurrentId());

    app.hook.receive(event, hwnd, id_object);
}
