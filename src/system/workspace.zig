const std = @import("std");
const win32 = @import("win32.zig");

const window_intent = @import("../core/window/intent.zig");

const assert = std.debug.assert;

const HWND = win32.HWND;
const BOOL = win32.BOOL;
const LPARAM = win32.LPARAM;
const RECT = win32.RECT;

const IntentQueue = window_intent.IntentQueue;
const RestoreMode = window_intent.RestoreMode;

pub const WORKSPACES_MAX = 8;
pub const WINDOWS_PER_WORKSPACE_MAX = 64;
const NAME_LEN_MAX = 32;
const TITLE_PROBE_LEN = 4;
const PINNED_MAX = 16;
const SELF_TITLE = "Prototype UI";
const WS_EX_LAYERED: u32 = 0x00080000;

const WindowMode = enum {
    normal,
    maximized,
    minimized_by_user,
};

const WindowState = struct {
    mode: WindowMode,
    rect: window_intent.Rect,
    was_layered: bool,
};

pub const Workspace = struct {
    handles: [WINDOWS_PER_WORKSPACE_MAX]isize,
    states: [WINDOWS_PER_WORKSPACE_MAX]WindowState,
    count: usize,
    name: [NAME_LEN_MAX]u8,
    name_length: usize,

    pub fn init_named(label: []const u8) Workspace {
        assert(label.len > 0);
        assert(label.len <= NAME_LEN_MAX);

        var ws = Workspace{
            .handles = undefined,
            .states = undefined,
            .count = 0,
            .name = undefined,
            .name_length = label.len,
        };

        @memcpy(ws.name[0..label.len], label);

        assert(ws.name_length == label.len);
        assert(ws.count == 0);

        return ws;
    }

    pub fn name_slice(self: *const Workspace) []const u8 {
        return self.name[0..self.name_length];
    }

    pub fn handles_slice(self: *const Workspace) []const isize {
        return self.handles[0..self.count];
    }

    pub fn contains(self: *const Workspace, handle: isize) bool {
        assert(handle != 0);

        for (self.handles[0..self.count]) |h| {
            if (h == handle) return true;
        }

        return false;
    }

    pub fn add(self: *Workspace, handle: isize) void {
        assert(handle != 0);
        assert(self.count < WINDOWS_PER_WORKSPACE_MAX);
        assert(!self.contains(handle));

        self.handles[self.count] = handle;
        self.states[self.count] = query_state(handle);
        self.count += 1;

        assert(self.count <= WINDOWS_PER_WORKSPACE_MAX);
        assert(self.contains(handle));
    }

    pub fn try_add(self: *Workspace, handle: isize) bool {
        if (handle == 0) return false;
        if (self.count >= WINDOWS_PER_WORKSPACE_MAX) return false;
        if (self.contains(handle)) return false;

        self.handles[self.count] = handle;
        self.states[self.count] = query_state(handle);
        self.count += 1;

        return true;
    }

    pub fn remove(self: *Workspace, handle: isize) void {
        assert(handle != 0);
        assert(self.count > 0);

        var i: usize = 0;

        while (i < self.count) : (i += 1) {
            if (self.handles[i] == handle) {
                self.handles[i] = self.handles[self.count - 1];
                self.states[i] = self.states[self.count - 1];
                self.count -= 1;

                assert(!self.contains(handle));

                return;
            }
        }

        unreachable;
    }

    pub fn hide(self: *Workspace, intents: *IntentQueue) void {
        self.sort_by_z_order();

        var i: usize = 0;

        while (i < self.count) : (i += 1) {
            self.states[i] = query_state(self.handles[i]);

            intents.append(.{ .minimize = self.handles[i] });
        }

        assert(i == self.count);
    }

    pub fn hide_untracked(
        self: *Workspace,
        manager: *const WorkspaceManager,
        intents: *IntentQueue,
    ) void {
        assert(self.count <= WINDOWS_PER_WORKSPACE_MAX);

        const remaining = WINDOWS_PER_WORKSPACE_MAX - self.count;

        var result = VisibleSweep{
            .manager = manager,
            .handles = undefined,
            .count = 0,
            .capacity = remaining,
        };

        _ = win32.EnumWindows(sweep_callback, @bitCast(@intFromPtr(&result)));

        assert(result.count <= remaining);

        var i: usize = 0;

        while (i < result.count) : (i += 1) {
            self.handles[self.count] = result.handles[i];
            self.states[self.count] = query_state(result.handles[i]);
            self.count += 1;

            intents.append(.{ .minimize = result.handles[i] });
        }

        assert(self.count <= WINDOWS_PER_WORKSPACE_MAX);
    }

    pub fn populate(self: *Workspace, source_handles: []const isize) void {
        self.count = 0;

        for (source_handles) |handle| {
            if (self.count >= WINDOWS_PER_WORKSPACE_MAX) break;
            if (handle == 0) continue;

            self.handles[self.count] = handle;
            self.states[self.count] = query_state(handle);
            self.count += 1;
        }

        assert(self.count <= WINDOWS_PER_WORKSPACE_MAX);
    }

    pub fn cleanup_dead(self: *Workspace) void {
        var i: usize = 0;

        while (i < self.count) {
            assert(self.handles[i] != 0);

            const hwnd = to_hwnd(self.handles[i]);

            if (win32.IsWindow(hwnd) == 0) {
                self.handles[i] = self.handles[self.count - 1];
                self.states[i] = self.states[self.count - 1];
                self.count -= 1;
            } else {
                i += 1;
            }
        }

        assert(self.count <= WINDOWS_PER_WORKSPACE_MAX);
    }

    fn sort_by_z_order(self: *Workspace) void {
        if (self.count <= 1) return;

        var ctx = ZOrderContext{
            .workspace = self,
            .sorted_handles = undefined,
            .sorted_states = undefined,
            .sorted_count = 0,
        };

        _ = win32.EnumWindows(z_order_callback, @bitCast(@intFromPtr(&ctx)));

        var i: usize = 0;

        while (i < self.count) : (i += 1) {
            if (!ctx.contains_handle(self.handles[i])) {
                if (ctx.sorted_count >= WINDOWS_PER_WORKSPACE_MAX) break;

                ctx.sorted_handles[ctx.sorted_count] = self.handles[i];
                ctx.sorted_states[ctx.sorted_count] = self.states[i];
                ctx.sorted_count += 1;
            }
        }

        @memcpy(self.handles[0..ctx.sorted_count], ctx.sorted_handles[0..ctx.sorted_count]);
        @memcpy(self.states[0..ctx.sorted_count], ctx.sorted_states[0..ctx.sorted_count]);
        self.count = ctx.sorted_count;

        assert(self.count <= WINDOWS_PER_WORKSPACE_MAX);
    }
};

pub const WorkspaceManager = struct {
    workspaces: [WORKSPACES_MAX]Workspace,
    count: usize,
    active_index: usize,
    switching: bool,
    pinned: [PINNED_MAX]isize,
    pinned_count: usize,
    cloaked_handles: [WINDOWS_PER_WORKSPACE_MAX]isize,
    cloaked_remove_layered: [WINDOWS_PER_WORKSPACE_MAX]bool,
    cloaked_count: usize,

    pub fn init() WorkspaceManager {
        var mgr = WorkspaceManager{
            .workspaces = undefined,
            .count = 1,
            .active_index = 0,
            .switching = false,
            .pinned = undefined,
            .pinned_count = 0,
            .cloaked_handles = undefined,
            .cloaked_remove_layered = undefined,
            .cloaked_count = 0,
        };

        mgr.workspaces[0] = Workspace.init_named("Desktop 1");

        assert(mgr.count == 1);
        assert(mgr.active_index == 0);
        assert(mgr.cloaked_count == 0);

        return mgr;
    }

    pub fn pin(self: *WorkspaceManager, handle: isize) void {
        assert(handle != 0);
        assert(self.pinned_count < PINNED_MAX);

        if (self.is_pinned(handle)) return;

        self.pinned[self.pinned_count] = handle;
        self.pinned_count += 1;

        self.remove_everywhere(handle);
    }

    pub fn is_pinned(self: *const WorkspaceManager, handle: isize) bool {
        if (handle == 0) return false;

        var i: usize = 0;

        while (i < self.pinned_count) : (i += 1) {
            if (self.pinned[i] == handle) return true;
        }

        return false;
    }

    pub fn active(self: *const WorkspaceManager) *const Workspace {
        assert(self.active_index < self.count);

        return &self.workspaces[self.active_index];
    }

    pub fn active_mut(self: *WorkspaceManager) *Workspace {
        assert(self.active_index < self.count);

        return &self.workspaces[self.active_index];
    }

    pub fn slice(self: *const WorkspaceManager) []const Workspace {
        return self.workspaces[0..self.count];
    }

    pub fn switch_to(self: *WorkspaceManager, index: usize, intents: *IntentQueue) void {
        assert(index < self.count);

        if (index == self.active_index) return;

        self.switching = true;
        defer self.switching = false;

        self.workspaces[self.active_index].hide(intents);
        self.workspaces[self.active_index].hide_untracked(self, intents);
        self.active_index = index;

        self.restore_active_cloaked(intents);

        intents.append(.focus_self);

        assert(self.active_index == index);
    }

    pub fn clear_flashes(self: *const WorkspaceManager, intents: *IntentQueue) void {
        const ws = self.active();
        var i: usize = 0;

        while (i < ws.count) : (i += 1) {
            intents.append(.{ .stop_flash = ws.handles[i] });
        }
    }

    pub fn create(self: *WorkspaceManager) !usize {
        if (self.count >= WORKSPACES_MAX) return error.WorkspaceLimitReached;

        var buf: [NAME_LEN_MAX]u8 = undefined;

        const name = std.mem.print(&buf, "Desktop {d}", .{
            self.count + 1,
        }) catch return error.WorkspaceLimitReached;

        self.workspaces[self.count] = Workspace.init_named(name);
        self.count += 1;

        assert(self.count <= WORKSPACES_MAX);

        return self.count - 1;
    }

    pub fn destroy(self: *WorkspaceManager, index: usize, intents: *IntentQueue) void {
        assert(index < self.count);
        assert(self.count > 1);

        const target_index: usize = if (index > 0) index - 1 else 1;

        assert(target_index < self.count);
        assert(target_index != index);

        if (!self.can_migrate(index, target_index)) return;

        self.switching = true;
        defer self.switching = false;

        self.migrate_windows(index, target_index);

        if (self.active_index == index) {
            self.active_index = target_index;

            self.restore_active_cloaked(intents);
        }

        self.shift_down(index);

        assert(self.count >= 1);
        assert(self.active_index < self.count);
    }

    pub fn move_window(
        self: *WorkspaceManager,
        handle: isize,
        target_index: usize,
        intents: *IntentQueue,
    ) void {
        assert(handle != 0);
        assert(target_index < self.count);

        if (self.workspaces[target_index].contains(handle)) return;
        if (self.workspaces[target_index].count >= WINDOWS_PER_WORKSPACE_MAX) return;

        self.remove_everywhere(handle);
        self.workspaces[target_index].add(handle);

        if (target_index != self.active_index) {
            intents.append(.{ .minimize = handle });
        }

        assert(self.workspaces[target_index].contains(handle));
    }

    pub fn is_tracked(self: *const WorkspaceManager, handle: isize) bool {
        if (handle == 0) return false;
        if (self.is_pinned(handle)) return true;

        var i: usize = 0;

        while (i < self.count) : (i += 1) {
            if (self.workspaces[i].contains(handle)) return true;
        }

        return false;
    }

    pub fn remove_everywhere(self: *WorkspaceManager, handle: isize) void {
        if (handle == 0) return;

        var i: usize = 0;

        while (i < self.count) : (i += 1) {
            if (self.workspaces[i].contains(handle)) {
                self.workspaces[i].remove(handle);
            }
        }
    }

    pub fn cleanup_dead_handles(self: *WorkspaceManager) void {
        var i: usize = 0;

        while (i < self.count) : (i += 1) {
            self.workspaces[i].cleanup_dead();
        }
    }

    pub fn uncloak_pending(self: *WorkspaceManager, intents: *IntentQueue) void {
        var i: usize = 0;

        while (i < self.cloaked_count) : (i += 1) {
            intents.append(.{ .uncloak = .{
                .handle = self.cloaked_handles[i],
                .remove_layered = self.cloaked_remove_layered[i],
            } });
        }

        self.cloaked_count = 0;

        assert(self.cloaked_count == 0);
    }

    fn restore_active_cloaked(self: *WorkspaceManager, intents: *IntentQueue) void {
        self.uncloak_pending(intents);

        const ws = self.active();
        if (ws.count == 0) return;

        var j: usize = 0;

        while (j < ws.count) : (j += 1) {
            if (ws.states[j].mode == .minimized_by_user) continue;

            intents.append(.{ .cloak = ws.handles[j] });

            assert(self.cloaked_count < WINDOWS_PER_WORKSPACE_MAX);

            self.cloaked_handles[self.cloaked_count] = ws.handles[j];
            self.cloaked_remove_layered[self.cloaked_count] = !ws.states[j].was_layered;
            self.cloaked_count += 1;
        }

        var i: usize = ws.count;

        while (i > 0) {
            i -= 1;

            intents.append(.{ .restore_active = .{
                .handle = ws.handles[i],
                .mode = to_restore_mode(ws.states[i].mode),
                .rect = ws.states[i].rect,
            } });
        }

        assert(self.cloaked_count <= ws.count);
    }

    fn can_migrate(
        self: *const WorkspaceManager,
        source_index: usize,
        target_index: usize,
    ) bool {
        assert(source_index < self.count);
        assert(target_index < self.count);
        assert(source_index != target_index);

        const source = &self.workspaces[source_index];
        const target = &self.workspaces[target_index];

        var needed: usize = 0;
        var j: usize = 0;

        while (j < source.count) : (j += 1) {
            if (!target.contains(source.handles[j])) {
                needed += 1;
            }
        }

        return target.count + needed <= WINDOWS_PER_WORKSPACE_MAX;
    }

    fn migrate_windows(self: *WorkspaceManager, source_index: usize, target_index: usize) void {
        assert(source_index < self.count);
        assert(target_index < self.count);
        assert(source_index != target_index);

        const source = &self.workspaces[source_index];
        var target = &self.workspaces[target_index];
        var j: usize = 0;

        while (j < source.count) : (j += 1) {
            if (!target.contains(source.handles[j])) {
                assert(target.count < WINDOWS_PER_WORKSPACE_MAX);

                target.handles[target.count] = source.handles[j];
                target.states[target.count] = source.states[j];
                target.count += 1;
            }
        }

        assert(target.count <= WINDOWS_PER_WORKSPACE_MAX);
    }

    fn shift_down(self: *WorkspaceManager, removed_index: usize) void {
        assert(removed_index < self.count);

        var i: usize = removed_index;

        while (i < self.count - 1) : (i += 1) {
            self.workspaces[i] = self.workspaces[i + 1];
        }

        self.count -= 1;

        if (self.active_index > removed_index) {
            self.active_index -= 1;
        }

        assert(self.count >= 1);
        assert(self.active_index < self.count);
    }
};

const ZOrderContext = struct {
    workspace: *const Workspace,
    sorted_handles: [WINDOWS_PER_WORKSPACE_MAX]isize,
    sorted_states: [WINDOWS_PER_WORKSPACE_MAX]WindowState,
    sorted_count: usize,

    fn contains_handle(self: *const ZOrderContext, handle: isize) bool {
        var i: usize = 0;

        while (i < self.sorted_count) : (i += 1) {
            if (self.sorted_handles[i] == handle) return true;
        }

        return false;
    }
};

fn z_order_callback(hwnd: HWND, lparam: LPARAM) callconv(.c) BOOL {
    const ctx: *ZOrderContext = @ptrFromInt(@as(usize, @bitCast(lparam)));
    const handle: isize = @bitCast(@intFromPtr(hwnd));
    if (handle == 0) return 1;
    if (ctx.sorted_count >= ctx.workspace.count) return 0;

    const ws = ctx.workspace;
    var i: usize = 0;

    while (i < ws.count) : (i += 1) {
        if (ws.handles[i] == handle) {
            ctx.sorted_handles[ctx.sorted_count] = handle;
            ctx.sorted_states[ctx.sorted_count] = ws.states[i];
            ctx.sorted_count += 1;

            return 1;
        }
    }

    return 1;
}

pub fn is_trackable_window(handle: isize) bool {
    if (handle == 0) return false;

    const hwnd = to_hwnd(handle);
    if (win32.IsWindow(hwnd) == 0) return false;
    if (win32.IsWindowVisible(hwnd) == 0) return false;
    if (is_self_window(hwnd)) return false;
    if (is_shell_window(hwnd)) return false;
    if (is_cloaked(hwnd)) return false;

    const style: u32 = @bitCast(win32.GetWindowLongW(hwnd, win32.GWL_STYLE));
    const ex_style: u32 = @bitCast(win32.GetWindowLongW(hwnd, win32.GWL_EXSTYLE));
    const WS_CHILD: u32 = 0x40000000;
    const WS_EX_TOOLWINDOW: u32 = 0x00000080;
    const WS_EX_APPWINDOW: u32 = 0x00040000;
    const WS_EX_NOACTIVATE: u32 = 0x08000000;

    if (style & WS_CHILD != 0) return false;
    if (ex_style & WS_EX_NOACTIVATE != 0) return false;

    const is_tool = ex_style & WS_EX_TOOLWINDOW != 0;
    const is_app = ex_style & WS_EX_APPWINDOW != 0;
    const has_owner = win32.GetWindow(hwnd, win32.GW_OWNER) != null;

    if (!is_app) {
        if (is_tool) return false;
        if (has_owner) return false;
    }

    var title_buf: [TITLE_PROBE_LEN]u16 = undefined;
    const len = win32.GetWindowTextW(hwnd, @ptrCast(&title_buf), TITLE_PROBE_LEN);
    if (len <= 0) return false;
    return true;
}

fn is_cloaked(hwnd: HWND) bool {
    const DWMWA_CLOAKED: u32 = 14;

    var cloaked: u32 = 0;

    const result = win32.DwmGetWindowAttribute(
        hwnd,
        @fromBackingInt(@intCast(DWMWA_CLOAKED)),
        @ptrCast(&cloaked),
        @sizeOf(u32),
    );

    if (result != win32.S_OK) return false;
    return cloaked != 0;
}

fn is_self_window(hwnd: HWND) bool {
    var buf: [64]u16 = undefined;
    const len = win32.GetWindowTextW(hwnd, @ptrCast(&buf), 64);
    if (len <= 0) return false;

    const ulen: usize = @intCast(len);
    if (ulen != SELF_TITLE.len) return false;

    var i: usize = 0;

    while (i < ulen) : (i += 1) {
        if (buf[i] != SELF_TITLE[i]) return false;
    }

    return true;
}

fn to_restore_mode(mode: WindowMode) RestoreMode {
    return switch (mode) {
        .normal => .normal,
        .maximized => .maximized,
        .minimized_by_user => .minimized,
    };
}

const VisibleSweep = struct {
    manager: *const WorkspaceManager,
    handles: [WINDOWS_PER_WORKSPACE_MAX]isize,
    count: usize,
    capacity: usize,
};

fn sweep_callback(hwnd: HWND, lparam: LPARAM) callconv(.c) BOOL {
    const sweep: *VisibleSweep = @ptrFromInt(@as(usize, @bitCast(lparam)));
    if (sweep.count >= sweep.capacity) return 0;

    const handle: isize = @bitCast(@intFromPtr(hwnd));
    if (handle == 0) return 1;
    if (!is_trackable_window(handle)) return 1;
    if (sweep.manager.is_tracked(handle)) return 1;
    if (win32.IsIconic(hwnd) != 0) return 1;

    sweep.handles[sweep.count] = handle;
    sweep.count += 1;

    return 1;
}

fn is_shell_window(hwnd: HWND) bool {
    var class_buf: [64]u16 = undefined;
    const len = win32.GetClassNameW(hwnd, @ptrCast(&class_buf), 64);
    if (len <= 0) return false;

    const ulen: usize = @intCast(len);
    const class = class_buf[0..ulen];
    if (match_class(class, "Shell_TrayWnd")) return true;
    if (match_class(class, "Shell_SecondaryTrayWnd")) return true;
    if (match_class(class, "Progman")) return true;
    if (match_class(class, "WorkerW")) return true;
    if (match_class(class, "NotifyIconOverflowWindow")) return true;
    if (match_class(class, "Windows.UI.Core.CoreWindow")) return true;
    return false;
}

fn match_class(wide: []const u16, ascii: []const u8) bool {
    if (wide.len != ascii.len) return false;

    for (wide, ascii) |w, a| {
        if (w != @as(u16, a)) return false;
    }

    return true;
}

fn query_state(handle: isize) WindowState {
    assert(handle != 0);

    const hwnd = to_hwnd(handle);

    var mode: WindowMode = .normal;
    var was_layered: bool = false;

    if (win32.IsWindow(hwnd) != 0) {
        if (win32.IsIconic(hwnd) != 0) {
            mode = .minimized_by_user;
        } else if (win32.IsZoomed(hwnd) == 0) {
            mode = .normal;
        } else {
            mode = .maximized;
        }

        const ex_style: u32 = @bitCast(win32.GetWindowLongW(hwnd, win32.GWL_EXSTYLE));
        was_layered = ex_style & WS_EX_LAYERED != 0;
    }

    if (mode == .minimized_by_user) {
        var placement: win32.WINDOWPLACEMENT = std.mem.zeroes(win32.WINDOWPLACEMENT);
        placement.length = @sizeOf(win32.WINDOWPLACEMENT);

        _ = win32.GetWindowPlacement(hwnd, &placement);

        const r = placement.rcNormalPosition;

        return .{
            .mode = mode,
            .rect = .{
                .left = r.left,
                .top = r.top,
                .right = r.right,
                .bottom = r.bottom,
            },
            .was_layered = was_layered,
        };
    }

    var win_rect: RECT = std.mem.zeroes(RECT);

    if (win32.IsWindow(hwnd) != 0) {
        _ = win32.GetWindowRect(hwnd, &win_rect);
    }

    return .{
        .mode = mode,
        .rect = .{
            .left = win_rect.left,
            .top = win_rect.top,
            .right = win_rect.right,
            .bottom = win_rect.bottom,
        },
        .was_layered = was_layered,
    };
}

fn to_hwnd(handle: isize) HWND {
    assert(handle != 0);

    return @ptrFromInt(@as(usize, @bitCast(handle)));
}
