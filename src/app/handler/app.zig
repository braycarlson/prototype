const std = @import("std");
const message = @import("../message.zig");
const state = @import("../state.zig");
const intent = @import("../../core/window/intent.zig");
const windows = @import("../../system/windows.zig");

const assert = std.debug.assert;

const App = message.App;
const Cmd = message.Cmd;
const IntentQueue = intent.IntentQueue;
const Model = state.Model;
const UiState = state.UiState;

pub fn handle(model: *Model, ui: *UiState, msg: App, intents: *IntentQueue) Cmd {
    _ = ui;
    _ = intents;

    return switch (msg) {
        .initialized => handle_initialized(model),
        .refresh_system_info => handle_refresh_system_info(model),
        .refresh_window_list => handle_refresh_window_list(model),
    };
}

fn handle_initialized(model: *Model) Cmd {
    assert(model.page == .home);
    assert(model.theme == .dark);

    return .none;
}

fn handle_refresh_system_info(model: *Model) Cmd {
    model.refresh_system_info();
    assert(model.system_info.hostname_length > 0);

    return .none;
}

fn handle_refresh_window_list(model: *Model) Cmd {
    model.refresh_window_list();
    assert(model.window_list.count <= windows.WINDOWS_MAX);

    return .none;
}
