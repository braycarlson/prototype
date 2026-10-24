const std = @import("std");
const win32 = @import("../../system/win32.zig");

const window_intent = @import("intent.zig");

const assert = std.debug.assert;

const HWND = win32.HWND;

const IntentQueue = window_intent.IntentQueue;
const Rect = window_intent.Rect;
const RestorePayload = window_intent.RestorePayload;
const BatchRaisePayload = window_intent.BatchRaisePayload;
const UncloakPayload = window_intent.UncloakPayload;
const WindowIntent = window_intent.WindowIntent;

const SELF_TITLE = "Prototype UI";
const WS_EX_LAYERED: u32 = 0x00080000;
const LWA_ALPHA: win32.LAYERED_WINDOW_ATTRIBUTES_FLAGS = @bitCast(@as(u32, 0x00000002));
const DWMWA_TRANSITIONS_FORCEDISABLED: u32 = 3;

pub fn execute(intents: *const IntentQueue) void {
    for (intents.slice()) |item| {
        execute_one(item);
    }
}

fn execute_one(item: WindowIntent) void {
    switch (item) {
        .minimize => |handle| execute_minimize(handle),
        .restore_quiet => |payload| execute_restore_quiet(payload),
        .restore_active => |payload| execute_restore_active(payload),
        .focus => |handle| execute_focus(handle),
        .stop_flash => |handle| execute_stop_flash(handle),
        .focus_self => execute_focus_self(),
        .raise => |handle| execute_raise(handle),
        .batch_raise => |payload| execute_batch_raise(payload),
        .cloak => |handle| execute_cloak(handle),
        .uncloak => |payload| execute_uncloak(payload),
    }
}

fn execute_minimize(handle: isize) void {
    assert(handle != 0);

    const hwnd = to_hwnd(handle);
    if (win32.IsWindow(hwnd) == 0) return;
    if (win32.IsIconic(hwnd) != 0) return;

    _ = win32.ShowWindow(hwnd, win32.SW_MINIMIZE);
}

fn execute_restore_quiet(payload: RestorePayload) void {
    assert(payload.handle != 0);

    const hwnd = to_hwnd(payload.handle);
    if (win32.IsWindow(hwnd) == 0) return;

    switch (payload.mode) {
        .normal => {
            _ = win32.ShowWindow(hwnd, win32.SW_SHOWNOACTIVATE);

            apply_rect(hwnd, payload.rect, .{
                .NOZORDER = 1,
                .NOACTIVATE = 1,
            });
        },
        .maximized => {
            apply_placement(hwnd, payload.rect, win32.SW_SHOWMAXIMIZED);
        },
        .minimized => {
            apply_placement(hwnd, payload.rect, win32.SW_SHOWMINNOACTIVE);
        },
    }
}

fn execute_restore_active(payload: RestorePayload) void {
    assert(payload.handle != 0);

    const hwnd = to_hwnd(payload.handle);
    if (win32.IsWindow(hwnd) == 0) return;

    switch (payload.mode) {
        .normal => {
            _ = win32.ShowWindow(hwnd, win32.SW_RESTORE);

            apply_rect(hwnd, payload.rect, .{ .NOZORDER = 1 });
        },
        .maximized => {
            apply_placement(hwnd, payload.rect, win32.SW_SHOWMAXIMIZED);
        },
        .minimized => {
            apply_placement(hwnd, payload.rect, win32.SW_SHOWMINNOACTIVE);
        },
    }
}

fn execute_focus(handle: isize) void {
    assert(handle != 0);

    const hwnd = to_hwnd(handle);

    if (win32.IsWindow(hwnd) != 0) {
        if (win32.IsIconic(hwnd) == 0) {
            _ = win32.SetForegroundWindow(hwnd);
        }
    }
}

fn execute_stop_flash(handle: isize) void {
    assert(handle != 0);

    const hwnd = to_hwnd(handle);

    var info: win32.FLASHWINFO = std.mem.zeroes(win32.FLASHWINFO);
    info.cbSize = @sizeOf(win32.FLASHWINFO);
    info.hwnd = hwnd;
    info.dwFlags = win32.FLASHW_STOP;
    info.uCount = 0;
    info.dwTimeout = 0;

    _ = win32.FlashWindowEx(&info);
}

fn execute_focus_self() void {
    const title_w = comptime blk: {
        var buf: [SELF_TITLE.len]u16 = undefined;

        for (0..SELF_TITLE.len) |i| {
            buf[i] = SELF_TITLE[i];
        }

        break :blk buf ++ [_]u16{0};
    };

    const hwnd = win32.FindWindowW(null, @ptrCast(&title_w));

    if (hwnd != null) {
        _ = win32.SetForegroundWindow(hwnd.?);
    }
}

fn execute_batch_raise(payload: BatchRaisePayload) void {
    assert(payload.count > 0);

    var live_count: i32 = 0;
    var k: usize = 0;

    while (k < payload.count) : (k += 1) {
        const h = payload.handles[k];
        if (h == 0) continue;

        const hwnd = to_hwnd(h);
        if (win32.IsWindow(hwnd) == 0) continue;
        if (win32.IsIconic(hwnd) != 0) continue;

        live_count += 1;
    }

    if (live_count == 0) return;

    var hdwp = win32.BeginDeferWindowPos(live_count);
    if (hdwp == 0) return;

    var i: usize = payload.count;

    while (i > 0) {
        i -= 1;

        const h = payload.handles[i];
        if (h == 0) continue;

        const hwnd = to_hwnd(h);
        if (win32.IsWindow(hwnd) == 0) continue;
        if (win32.IsIconic(hwnd) != 0) continue;

        hdwp = win32.DeferWindowPos(
            hdwp,
            hwnd,
            null,
            0,
            0,
            0,
            0,
            .{ .NOMOVE = 1, .NOSIZE = 1, .NOACTIVATE = 1 },
        );

        if (hdwp == 0) return;
    }

    _ = win32.EndDeferWindowPos(hdwp);

    if (payload.focus_handle != 0) {
        const focus_hwnd = to_hwnd(payload.focus_handle);

        if (win32.IsWindow(focus_hwnd) != 0) {
            if (win32.IsIconic(focus_hwnd) == 0) {
                _ = win32.SetForegroundWindow(focus_hwnd);
            }
        }
    }
}

fn execute_cloak(handle: isize) void {
    assert(handle != 0);

    const hwnd = to_hwnd(handle);
    if (win32.IsWindow(hwnd) == 0) return;

    var disable: win32.BOOL = 1;

    _ = win32.DwmSetWindowAttribute(
        hwnd,
        @fromBackingInt(@intCast(DWMWA_TRANSITIONS_FORCEDISABLED)),
        @ptrCast(&disable),
        @sizeOf(win32.BOOL),
    );

    const ex_style: u32 = @bitCast(win32.GetWindowLongW(hwnd, win32.GWL_EXSTYLE));

    if (ex_style & WS_EX_LAYERED == 0) {
        _ = win32.SetWindowLongW(hwnd, win32.GWL_EXSTYLE, @bitCast(ex_style | WS_EX_LAYERED));
    }

    _ = win32.SetLayeredWindowAttributes(hwnd, 0, 0, LWA_ALPHA);
}

fn execute_uncloak(payload: UncloakPayload) void {
    assert(payload.handle != 0);

    const hwnd = to_hwnd(payload.handle);
    if (win32.IsWindow(hwnd) == 0) return;

    _ = win32.SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);

    if (payload.remove_layered) {
        const ex_style: u32 = @bitCast(win32.GetWindowLongW(hwnd, win32.GWL_EXSTYLE));

        assert(ex_style & WS_EX_LAYERED != 0);

        _ = win32.SetWindowLongW(hwnd, win32.GWL_EXSTYLE, @bitCast(ex_style & ~WS_EX_LAYERED));
    }

    var enable: win32.BOOL = 0;

    _ = win32.DwmSetWindowAttribute(
        hwnd,
        @fromBackingInt(@intCast(DWMWA_TRANSITIONS_FORCEDISABLED)),
        @ptrCast(&enable),
        @sizeOf(win32.BOOL),
    );
}

fn execute_raise(handle: isize) void {
    assert(handle != 0);

    const hwnd = to_hwnd(handle);
    if (win32.IsWindow(hwnd) == 0) return;
    if (win32.IsIconic(hwnd) != 0) return;

    _ = win32.SetWindowPos(
        hwnd,
        null,
        0,
        0,
        0,
        0,
        .{ .NOMOVE = 1, .NOSIZE = 1 },
    );
}

fn apply_rect(hwnd: HWND, rect: Rect, flags: win32.SET_WINDOW_POS_FLAGS) void {
    assert(rect.right >= rect.left);
    assert(rect.bottom >= rect.top);

    _ = win32.SetWindowPos(
        hwnd,
        null,
        rect.left,
        rect.top,
        rect.right - rect.left,
        rect.bottom - rect.top,
        flags,
    );
}

fn apply_placement(hwnd: HWND, rect: Rect, show_cmd: win32.SHOW_WINDOW_CMD) void {
    assert(rect.right >= rect.left);
    assert(rect.bottom >= rect.top);

    var placement: win32.WINDOWPLACEMENT = std.mem.zeroes(win32.WINDOWPLACEMENT);
    placement.length = @sizeOf(win32.WINDOWPLACEMENT);

    _ = win32.GetWindowPlacement(hwnd, &placement);

    placement.rcNormalPosition = .{
        .left = rect.left,
        .top = rect.top,
        .right = rect.right,
        .bottom = rect.bottom,
    };

    placement.showCmd = show_cmd;

    _ = win32.SetWindowPlacement(hwnd, &placement);
}

fn to_hwnd(handle: isize) HWND {
    assert(handle != 0);

    return @ptrFromInt(@as(usize, @bitCast(handle)));
}
