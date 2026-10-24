const std = @import("std");

const nimble = @import("nimble");

const win32 = @import("win32.zig");

const assert = std.debug.assert;

const HWND = win32.HWND;
const Mutex = nimble.Mutex;

const OBJID_WINDOW: i32 = 0;
const WINEVENT_OUTOFCONTEXT: u32 = 0x0000;
pub const EVENTS_PENDING_MAX: usize = 256;
pub const ready_yield_max: u32 = 1 << 20;

pub const EventKind = enum {
    window_shown,
    window_destroyed,
};

pub const HookEvent = struct {
    kind: EventKind,
    handle: isize,
};

var event_buffer: EventBuffer = .{};
var hook_installed = std.atomic.Value(bool).init(false);
var hook_ready = std.atomic.Value(bool).init(false);

const EventBuffer = struct {
    mutex: Mutex = .{},
    events: [EVENTS_PENDING_MAX]HookEvent = undefined,
    count: usize = 0,
};

pub fn install() void {
    assert(!hook_installed.load(.acquire));

    const thread = std.Thread.spawn(.{}, run_hook_thread, .{}) catch |err| {
        std.debug.panic("the hook thread failed to spawn: {s}", .{@errorName(err)});
    };

    thread.detach();

    wait_ready();

    assert(hook_installed.load(.acquire));
}

fn wait_ready() void {
    var attempts: u32 = 0;

    while (attempts < ready_yield_max) : (attempts += 1) {
        assert(attempts < ready_yield_max);

        if (hook_ready.load(.acquire)) {
            break;
        }

        std.Thread.yield() catch continue;
    }
}

pub fn drain(out: *[EVENTS_PENDING_MAX]HookEvent) usize {
    event_buffer.mutex.lock();
    defer event_buffer.mutex.unlock();

    const n = event_buffer.count;

    if (n > 0) {
        @memcpy(out[0..n], event_buffer.events[0..n]);
        event_buffer.count = 0;
    }

    return n;
}

pub fn is_installed() bool {
    return hook_installed.load(.acquire);
}

fn push(event: HookEvent) void {
    event_buffer.mutex.lock();
    defer event_buffer.mutex.unlock();

    if (event_buffer.count >= EVENTS_PENDING_MAX) return;

    event_buffer.events[event_buffer.count] = event;
    event_buffer.count += 1;
}

fn event_callback(
    _: ?win32.HWINEVENTHOOK,
    event: u32,
    hwnd: ?HWND,
    id_object: i32,
    _: i32,
    _: u32,
    _: u32,
) callconv(.c) void {
    if (id_object != OBJID_WINDOW) return;

    const raw_hwnd = hwnd orelse return;
    const handle: isize = @bitCast(@intFromPtr(raw_hwnd));
    if (handle == 0) return;

    const kind: EventKind = classify_event(event) orelse return;

    push(.{ .kind = kind, .handle = handle });
}

fn classify_event(event: u32) ?EventKind {
    return switch (event) {
        win32.EVENT_OBJECT_SHOW, win32.EVENT_OBJECT_CREATE => .window_shown,
        win32.EVENT_OBJECT_DESTROY => .window_destroyed,
        else => null,
    };
}

fn run_hook_thread() void {
    comptime assert(win32.EVENT_OBJECT_DESTROY == win32.EVENT_OBJECT_CREATE + 1);
    comptime assert(win32.EVENT_OBJECT_SHOW == win32.EVENT_OBJECT_DESTROY + 1);

    const hook = win32.SetWinEventHook(
        win32.EVENT_OBJECT_CREATE,
        win32.EVENT_OBJECT_SHOW,
        null,
        event_callback,
        0,
        0,
        WINEVENT_OUTOFCONTEXT,
    );

    hook_installed.store(hook != null, .release);
    hook_ready.store(true, .release);

    assert(hook != null);

    var msg: win32.MSG = std.mem.zeroes(win32.MSG);

    while (win32.GetMessageW(&msg, null, 0, 0) != 0) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }
}
