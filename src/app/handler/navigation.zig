const message = @import("../message.zig");
const state = @import("../state.zig");
const intent = @import("../../core/window/intent.zig");

const Cmd = message.Cmd;
const IntentQueue = intent.IntentQueue;
const Model = state.Model;
const Navigation = message.Navigation;
const UiState = state.UiState;

pub fn handle(model: *Model, ui: *UiState, msg: Navigation, intents: *IntentQueue) Cmd {
    _ = ui;
    _ = intents;

    return switch (msg) {
        .home => handle_home(model),
        .windows => handle_windows(model),
        .workspaces => handle_workspaces(model),
        .settings => handle_settings(model),
    };
}

fn handle_home(model: *Model) Cmd {
    model.page = .home;

    return .none;
}

fn handle_windows(model: *Model) Cmd {
    model.page = .windows;

    model.refresh_window_list();

    return .none;
}

fn handle_workspaces(model: *Model) Cmd {
    model.page = .workspaces;

    model.refresh_window_list();

    return .none;
}

fn handle_settings(model: *Model) Cmd {
    model.page = .settings;

    return .none;
}
