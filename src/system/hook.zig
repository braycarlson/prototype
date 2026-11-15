const std = @import("std");

const nimble = @import("nimble");

const win32 = @import("win32.zig");

const assert = std.debug.assert;

const HWND = win32.HWND;
const Mutex = nimble.Mutex;

const OBJID_WINDOW: i32 = 0;
const PM_NOREMOVE: u32 = 0x0000;
const WINEVENT_OUTOFCONTEXT: u32 = 0x0000;
const WM_QUIT: u32 = 0x0012;
const WM_USER: u32 = 0x0400;
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

pub const Hook = struct {
    buffer: EventBuffer,
    installed: std.atomic.Value(bool),
    ready: std.atomic.Value(bool),
    thread: std.Thread,
    thread_id: std.Thread.Id,

    pub fn init(hook: *Hook, procedure: win32.WINEVENTPROC) void {
        hook.* = .{
            .buffer = .{},
            .installed = .init(false),
            .ready = .init(false),
            .thread = undefined,
            .thread_id = 0,
        };

        hook.thread = std.Thread.spawn(.{}, run, .{ hook, procedure }) catch |err| {
            std.debug.panic("the hook thread failed to spawn: {s}", .{@errorName(err)});
        };

        hook.wait_ready();

        assert(hook.installed.load(.acquire));
        assert(hook.thread_id != 0);
    }

    pub fn deinit(hook: *Hook) void {
        assert(hook.installed.load(.acquire));
        assert(hook.thread_id != 0);

        const posted = win32.PostThreadMessageW(hook.thread_id, WM_QUIT, 0, 0);

        assert(posted != 0);

        hook.thread.join();
        hook.* = undefined;
    }

    pub fn drain(hook: *Hook, out: *[EVENTS_PENDING_MAX]HookEvent) usize {
        const count = hook.buffer.drain(out);

        assert(count <= EVENTS_PENDING_MAX);

        return count;
    }

    pub fn is_installed(hook: *const Hook) bool {
        return hook.installed.load(.acquire);
    }

    pub fn receive(hook: *Hook, event: u32, hwnd: ?HWND, id_object: i32) void {
        const decoded = decode(event, hwnd, id_object) orelse return;

        hook.buffer.push(decoded);
    }

    fn wait_ready(hook: *const Hook) void {
        var attempts: u32 = 0;

        while (attempts < ready_yield_max) : (attempts += 1) {
            assert(attempts < ready_yield_max);

            if (hook.ready.load(.acquire)) {
                break;
            }

            std.Thread.yield() catch continue;
        }
    }

    fn run(hook: *Hook, procedure: win32.WINEVENTPROC) void {
        comptime assert(win32.EVENT_OBJECT_DESTROY == win32.EVENT_OBJECT_CREATE + 1);
        comptime assert(win32.EVENT_OBJECT_SHOW == win32.EVENT_OBJECT_DESTROY + 1);

        var msg: win32.MSG = std.mem.zeroes(win32.MSG);

        _ = win32.PeekMessageW(&msg, null, WM_USER, WM_USER, PM_NOREMOVE);

        hook.thread_id = std.Thread.getCurrentId();

        const handle = win32.SetWinEventHook(
            win32.EVENT_OBJECT_CREATE,
            win32.EVENT_OBJECT_SHOW,
            null,
            procedure,
            0,
            0,
            WINEVENT_OUTOFCONTEXT,
        );

        hook.installed.store(handle != null, .release);
        hook.ready.store(true, .release);

        assert(handle != null);

        while (win32.GetMessageW(&msg, null, 0, 0) > 0) {
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageW(&msg);
        }

        const removed = win32.UnhookWinEvent(handle);

        assert(removed != 0);
    }
};

const EventBuffer = struct {
    mutex: Mutex = .{},
    events: [EVENTS_PENDING_MAX]HookEvent = undefined,
    count: usize = 0,

    fn drain(buffer: *EventBuffer, out: *[EVENTS_PENDING_MAX]HookEvent) usize {
        buffer.mutex.lock();
        defer buffer.mutex.unlock();

        const n = buffer.count;

        if (n > 0) {
            @memcpy(out[0..n], buffer.events[0..n]);
            buffer.count = 0;
        }

        return n;
    }

    fn push(buffer: *EventBuffer, event: HookEvent) void {
        buffer.mutex.lock();
        defer buffer.mutex.unlock();

        if (buffer.count >= EVENTS_PENDING_MAX) return;

        buffer.events[buffer.count] = event;
        buffer.count += 1;
    }
};

fn decode(event: u32, hwnd: ?HWND, id_object: i32) ?HookEvent {
    if (id_object != OBJID_WINDOW) return null;

    const raw_hwnd = hwnd orelse return null;
    const handle: isize = @bitCast(@intFromPtr(raw_hwnd));
    if (handle == 0) return null;

    const kind: EventKind = classify_event(event) orelse return null;

    return .{ .kind = kind, .handle = handle };
}

fn classify_event(event: u32) ?EventKind {
    return switch (event) {
        win32.EVENT_OBJECT_SHOW, win32.EVENT_OBJECT_CREATE => .window_shown,
        win32.EVENT_OBJECT_DESTROY => .window_destroyed,
        else => null,
    };
}

const testing = std.testing;

test "a window event decodes and every other event is dropped" {
    const EVENT_OBJECT_HIDE: u32 = 32771;
    const OBJID_CLIENT: i32 = -4;
    const hwnd: HWND = @ptrFromInt(0x1000);

    const cases = [_]struct { event: u32, kind: EventKind }{
        .{ .event = win32.EVENT_OBJECT_CREATE, .kind = .window_shown },
        .{ .event = win32.EVENT_OBJECT_SHOW, .kind = .window_shown },
        .{ .event = win32.EVENT_OBJECT_DESTROY, .kind = .window_destroyed },
    };

    for (cases) |case| {
        const decoded = decode(case.event, hwnd, OBJID_WINDOW) orelse return error.EventDropped;

        try testing.expectEqual(case.kind, decoded.kind);
        try testing.expectEqual(@as(isize, 0x1000), decoded.handle);
    }

    try testing.expect(decode(EVENT_OBJECT_HIDE, hwnd, OBJID_WINDOW) == null);
    try testing.expect(decode(win32.EVENT_OBJECT_SHOW, hwnd, OBJID_CLIENT) == null);
    try testing.expect(decode(win32.EVENT_OBJECT_SHOW, null, OBJID_WINDOW) == null);
}

test "the event buffer drains what fits in arrival order and drops the overflow" {
    const overflow_count: usize = 8;
    var buffer: EventBuffer = .{};
    var out: [EVENTS_PENDING_MAX]HookEvent = undefined;

    for (0..EVENTS_PENDING_MAX + overflow_count) |index| {
        buffer.push(.{ .kind = .window_shown, .handle = @intCast(index + 1) });
    }

    const count = buffer.drain(&out);

    try testing.expectEqual(EVENTS_PENDING_MAX, count);

    for (out[0..count], 1..) |event, handle| {
        try testing.expectEqual(@as(isize, @intCast(handle)), event.handle);
    }

    try testing.expectEqual(@as(usize, 0), buffer.drain(&out));
}
