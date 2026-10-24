const std = @import("std");
const win32 = @import("win32.zig");

const assert = std.debug.assert;

const HWND = win32.HWND;
const BOOL = win32.BOOL;
const LPARAM = win32.LPARAM;

pub const WINDOWS_MAX = 256;
const TITLE_LEN_MAX = 256;

pub const WindowEntry = struct {
    title: [TITLE_LEN_MAX]u8,
    title_length: usize,
    handle: isize,

    pub fn title_slice(self: *const WindowEntry) []const u8 {
        return self.title[0..self.title_length];
    }
};

pub const WindowList = struct {
    entries: [WINDOWS_MAX]WindowEntry,
    count: usize,

    pub fn query() WindowList {
        var result = WindowList{
            .entries = undefined,
            .count = 0,
        };

        _ = win32.EnumWindows(enum_callback, @bitCast(@intFromPtr(&result)));

        assert(result.count <= WINDOWS_MAX);

        return result;
    }

    pub fn slice(self: *const WindowList) []const WindowEntry {
        return self.entries[0..self.count];
    }
};

fn enum_callback(hwnd: HWND, lparam: LPARAM) callconv(.c) BOOL {
    const list: *WindowList = @ptrFromInt(@as(usize, @bitCast(lparam)));
    if (list.count >= WINDOWS_MAX) return 0;
    if (win32.IsWindowVisible(hwnd) == 0) return 1;

    var wide_buf: [TITLE_LEN_MAX]u16 = undefined;
    const len = win32.GetWindowTextW(hwnd, @ptrCast(&wide_buf), TITLE_LEN_MAX);
    if (len <= 0) return 1;

    const ulen: usize = @intCast(len);

    assert(ulen <= TITLE_LEN_MAX);

    var entry = &list.entries[list.count];
    entry.handle = @bitCast(@intFromPtr(hwnd));

    const title_length = @min(ulen, TITLE_LEN_MAX);
    var i: usize = 0;

    while (i < title_length) : (i += 1) {
        entry.title[i] = if (wide_buf[i] <= 0x7F)
            @truncate(wide_buf[i])
        else
            '?';
    }

    entry.title_length = i;

    list.count += 1;

    return 1;
}
