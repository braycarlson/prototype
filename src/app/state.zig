const std = @import("std");
const system_info = @import("../system/info.zig");
const system_windows = @import("../system/windows.zig");
const workspace = @import("../system/workspace.zig");

const assert = std.debug.assert;

pub const ThemeMode = enum {
    dark,
    light,
};

pub const Page = enum {
    home,
    windows,
    workspaces,
    settings,
};

pub const Model = struct {
    page: Page,
    system_info: system_info.SystemInfo,
    theme: ThemeMode,
    window_list: system_windows.WindowList,
    workspace_manager: workspace.WorkspaceManager,

    pub fn init() Model {
        const info = system_info.SystemInfo.query();
        const windows = system_windows.WindowList.query();
        var ws_mgr = workspace.WorkspaceManager.init();

        assert(info.hostname_length > 0);
        assert(windows.count <= system_windows.WINDOWS_MAX);
        assert(ws_mgr.count == 1);

        var handles: [workspace.WINDOWS_PER_WORKSPACE_MAX]isize = undefined;
        var handle_count: usize = 0;

        for (windows.slice()) |*entry| {
            if (handle_count >= workspace.WINDOWS_PER_WORKSPACE_MAX) break;
            if (!workspace.is_trackable_window(entry.handle)) continue;

            handles[handle_count] = entry.handle;
            handle_count += 1;
        }

        ws_mgr.active_mut().populate(handles[0..handle_count]);

        return .{
            .page = .home,
            .system_info = info,
            .theme = .dark,
            .window_list = windows,
            .workspace_manager = ws_mgr,
        };
    }

    pub fn refresh_system_info(self: *Model) void {
        self.system_info = system_info.SystemInfo.query();

        assert(self.system_info.hostname_length > 0);
    }

    pub fn refresh_window_list(self: *Model) void {
        self.window_list = system_windows.WindowList.query();

        assert(self.window_list.count <= system_windows.WINDOWS_MAX);
    }

    pub fn deinit(self: *Model) void {
        _ = self;
    }
};

pub const UiState = struct {
    about_show: bool,
    options_show: bool,
    sidebar_collapsed: bool,

    pub fn init() UiState {
        return .{
            .about_show = false,
            .options_show = false,
            .sidebar_collapsed = false,
        };
    }
};
