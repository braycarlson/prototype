const std = @import("std");
const dvui = @import("dvui");

const message = @import("../app/message.zig");
const state = @import("../app/state.zig");
const system_windows = @import("../system/windows.zig");
const workspace = @import("../system/workspace.zig");

const assert = std.debug.assert;

const Model = state.Model;
const Msg = message.Msg;
const MsgQueue = message.MsgQueue;
const Navigation = message.Navigation;
const Page = state.Page;
const UiState = state.UiState;

const SIDEBAR_EXPANDED: f32 = 220.0;
const SIDEBAR_COLLAPSED: f32 = 48.0;

comptime {
    const page_fields = @typeInfo(Page).@"enum".field_names;
    const nav_fields = @typeInfo(Navigation).@"enum".field_names;

    assert(page_fields.len == nav_fields.len);
}

pub fn render(model: *const Model, ui: *const UiState, queue: *MsgQueue) void {
    assert(model.workspace_manager.count >= 1);
    assert(model.workspace_manager.active_index < model.workspace_manager.count);

    apply_theme(model);

    var outer = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .both,
        .background = true,
        .style = .window,
    });

    defer outer.deinit();

    render_sidebar(model, ui, queue);
    render_content(model, queue);
}

fn apply_theme(model: *const Model) void {
    switch (model.theme) {
        .dark => dvui.themeSet(dvui.Theme.builtin.adwaita_dark),
        .light => dvui.themeSet(dvui.Theme.builtin.adwaita_light),
    }
}

fn render_sidebar(model: *const Model, ui: *const UiState, queue: *MsgQueue) void {
    const width: f32 = if (ui.sidebar_collapsed) SIDEBAR_COLLAPSED else SIDEBAR_EXPANDED;

    assert(width > 0.0);

    var sidebar = dvui.box(@src(), .{ .dir = .vertical }, .{
        .min_size_content = .{ .w = width },
        .max_size_content = .{ .w = width, .h = 0 },
        .background = true,
        .expand = .vertical,
        .padding = .all(8),
    });

    defer sidebar.deinit();

    if (ui.sidebar_collapsed) {
        render_sidebar_collapsed(queue);
    } else {
        dvui.label(@src(), "Prototype", .{}, .{
            .font = .theme(.heading),
            .margin = .{ .h = 16 },
        });

        render_nav_button(@src(), "Home", .home, model.page, queue);
        render_nav_button(@src(), "Windows", .windows, model.page, queue);
        render_nav_button(@src(), "Workspaces", .workspaces, model.page, queue);
        render_nav_button(@src(), "Settings", .settings, model.page, queue);

        if (dvui.button(@src(), "Collapse", .{}, .{
            .expand = .horizontal,
            .gravity_y = 1.0,
        })) {
            queue.append(.{ .sidebar = .toggle });
        }
    }
}

fn render_sidebar_collapsed(queue: *MsgQueue) void {
    if (dvui.buttonIcon(@src(), "home", dvui.entypo.home, .{}, .{}, .{
        .expand = .horizontal,
        .margin = .{ .h = 4 },
    })) {
        queue.append(.{ .navigation = .home });
    }

    if (dvui.buttonIcon(@src(), "windows", dvui.entypo.browser, .{}, .{}, .{
        .expand = .horizontal,
        .margin = .{ .h = 4 },
    })) {
        queue.append(.{ .navigation = .windows });
    }

    if (dvui.buttonIcon(@src(), "workspaces", dvui.entypo.list, .{}, .{}, .{
        .expand = .horizontal,
        .margin = .{ .h = 4 },
    })) {
        queue.append(.{ .navigation = .workspaces });
    }

    if (dvui.buttonIcon(@src(), "settings", dvui.entypo.cog, .{}, .{}, .{
        .expand = .horizontal,
        .margin = .{ .h = 4 },
    })) {
        queue.append(.{ .navigation = .settings });
    }

    if (dvui.buttonIcon(@src(), "expand", dvui.entypo.chevron_right, .{}, .{}, .{
        .expand = .horizontal,
        .gravity_y = 1.0,
    })) {
        queue.append(.{ .sidebar = .toggle });
    }
}

fn render_nav_button(
    src: std.lang.SourceLocation,
    label: []const u8,
    page: Page,
    current: Page,
    queue: *MsgQueue,
) void {
    const is_active = current == page;

    if (dvui.button(src, label, .{}, .{
        .expand = .horizontal,
        .margin = .{ .h = 2 },
        .background = is_active,
    })) {
        const msg: Msg = switch (page) {
            .home => .{ .navigation = .home },
            .windows => .{ .navigation = .windows },
            .workspaces => .{ .navigation = .workspaces },
            .settings => .{ .navigation = .settings },
        };

        queue.append(msg);
    }
}

fn render_content(model: *const Model, queue: *MsgQueue) void {
    var content = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .padding = .all(16),
    });

    defer content.deinit();

    switch (model.page) {
        .home => render_home(model, queue),
        .windows => render_windows(model, queue),
        .workspaces => render_workspaces(model, queue),
        .settings => render_settings(model, queue),
    }
}

fn render_home(model: *const Model, queue: *MsgQueue) void {
    assert(model.page == .home);
    assert(model.system_info.hostname_length > 0);

    dvui.label(@src(), "Home", .{}, .{
        .font = .theme(.heading),
        .margin = .{ .h = 12 },
    });

    const info = &model.system_info;

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .h = 4 } });
        defer row.deinit();

        dvui.label(@src(), "Hostname:", .{}, .{ .font = .theme(.heading) });
        dvui.labelNoFmt(@src(), info.hostname_slice(), .{}, .{ .margin = .{ .x = 8 } });
    }

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .margin = .{ .h = 4 } });
        defer row.deinit();

        dvui.label(@src(), "Memory:", .{}, .{ .font = .theme(.heading) });

        var buf: [128]u8 = undefined;

        const text = std.mem.print(&buf, "{d} MB / {d} MB ({d}%)", .{
            info.memory_mb_used(),
            info.memory_mb_total,
            info.memory_percent_load,
        }) catch "N/A";

        dvui.labelNoFmt(@src(), text, .{}, .{ .margin = .{ .x = 8 } });
    }

    if (dvui.button(@src(), "Refresh", .{}, .{ .margin = .{ .y = 12 } })) {
        queue.append(.{ .app = .refresh_system_info });
    }
}

fn render_windows(model: *const Model, queue: *MsgQueue) void {
    assert(model.page == .windows);
    assert(model.window_list.count <= system_windows.WINDOWS_MAX);

    {
        var header = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .margin = .{ .h = 8 },
        });

        defer header.deinit();

        dvui.label(@src(), "Windows", .{}, .{ .font = .theme(.heading) });

        var buf: [32]u8 = undefined;

        const visible_label = std.mem.print(&buf, "({d} visible)", .{
            model.window_list.count,
        }) catch "";

        dvui.labelNoFmt(@src(), visible_label, .{}, .{
            .margin = .{ .x = 8 },
            .gravity_y = 0.5,
        });

        if (dvui.button(@src(), "Refresh", .{}, .{
            .margin = .{ .x = 12 },
            .gravity_y = 0.5,
        })) {
            queue.append(.{ .app = .refresh_window_list });
        }
    }

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    for (model.window_list.slice(), 0..) |*entry, i| {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .padding = .all(4),
            .margin = .{ .h = 1 },
            .id_extra = i,
        });

        defer row.deinit();

        dvui.labelNoFmt(@src(), entry.title_slice(), .{}, .{
            .expand = .horizontal,
            .id_extra = i,
        });
    }
}

fn render_workspaces(model: *const Model, queue: *MsgQueue) void {
    assert(model.page == .workspaces);
    assert(model.workspace_manager.count >= 1);

    dvui.label(@src(), "Workspaces", .{}, .{
        .font = .theme(.heading),
        .margin = .{ .h = 8 },
    });

    render_workspace_tabs(model, queue);
    render_workspace_actions(model, queue);
    render_workspace_window_list(model, queue);
}

fn render_workspace_tabs(model: *const Model, queue: *MsgQueue) void {
    const ws_mgr = &model.workspace_manager;

    assert(ws_mgr.active_index < ws_mgr.count);

    var tabs = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .margin = .{ .h = 4 },
    });

    defer tabs.deinit();

    for (ws_mgr.slice(), 0..) |*ws, i| {
        const is_active = i == ws_mgr.active_index;

        if (dvui.button(@src(), ws.name_slice(), .{}, .{
            .margin = .{ .w = 4 },
            .background = is_active,
            .id_extra = i,
        })) {
            queue.append(.{ .workspace = .{ .switch_to = i } });
        }
    }
}

fn render_workspace_actions(model: *const Model, queue: *MsgQueue) void {
    const ws_mgr = &model.workspace_manager;

    assert(ws_mgr.count >= 1);
    assert(ws_mgr.count <= workspace.WORKSPACES_MAX);

    var actions = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .margin = .{ .h = 4 },
    });

    defer actions.deinit();

    if (ws_mgr.count < workspace.WORKSPACES_MAX) {
        if (dvui.button(@src(), "New", .{}, .{ .margin = .{ .w = 4 } })) {
            queue.append(.{ .workspace = .create });
        }
    }

    if (ws_mgr.count > 1) {
        if (dvui.button(@src(), "Remove", .{}, .{ .margin = .{ .w = 4 } })) {
            queue.append(.{ .workspace = .{ .destroy = ws_mgr.active_index } });
        }
    }

    var status_buf: [48]u8 = undefined;

    const status_text = std.mem.print(&status_buf, "{d} windows tracked", .{
        ws_mgr.active().count,
    }) catch "";

    dvui.labelNoFmt(@src(), status_text, .{}, .{
        .gravity_y = 0.5,
        .margin = .{ .x = 8 },
    });
}

fn render_workspace_window_list(model: *const Model, queue: *MsgQueue) void {
    const ws_mgr = &model.workspace_manager;
    const active_ws = ws_mgr.active();

    assert(active_ws.count <= workspace.WINDOWS_PER_WORKSPACE_MAX);

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    for (active_ws.handles_slice(), 0..) |handle, i| {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .padding = .all(4),
            .margin = .{ .h = 1 },
            .id_extra = i,
        });

        defer row.deinit();

        const title = find_title_by_handle(model, handle);

        dvui.labelNoFmt(@src(), title, .{}, .{
            .expand = .horizontal,
            .id_extra = i,
        });

        if (ws_mgr.count > 1) {
            const index_next = (ws_mgr.active_index + 1) % ws_mgr.count;

            if (dvui.button(@src(), "Move", .{}, .{
                .margin = .{ .x = 4 },
                .id_extra = i,
            })) {
                queue.append(.{ .workspace = .{ .move_window = .{
                    .handle = handle,
                    .target_index = index_next,
                } } });
            }
        }
    }
}

fn find_title_by_handle(model: *const Model, handle: isize) []const u8 {
    assert(handle != 0);

    for (model.window_list.slice()) |*entry| {
        if (entry.handle == handle) return entry.title_slice();
    }

    return "(Hidden)";
}

fn render_settings(model: *const Model, queue: *MsgQueue) void {
    assert(model.page == .settings);

    dvui.label(@src(), "Settings", .{}, .{
        .font = .theme(.heading),
        .margin = .{ .h = 12 },
    });

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .margin = .{ .h = 8 },
        });

        defer row.deinit();

        dvui.label(@src(), "Theme:", .{}, .{
            .gravity_y = 0.5,
            .margin = .{ .w = 8 },
        });

        const theme_label = switch (model.theme) {
            .dark => "Dark",
            .light => "Light",
        };

        if (dvui.button(@src(), theme_label, .{}, .{})) {
            queue.append(.{ .theme = .toggle });
        }
    }
}
