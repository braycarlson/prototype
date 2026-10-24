const message = @import("../message.zig");
const state = @import("../state.zig");
const intent = @import("../../core/window/intent.zig");

const Cmd = message.Cmd;
const IntentQueue = intent.IntentQueue;
const Model = state.Model;
const Sidebar = message.Sidebar;
const UiState = state.UiState;

pub fn handle(model: *Model, ui: *UiState, msg: Sidebar, intents: *IntentQueue) Cmd {
    _ = model;
    _ = intents;

    return switch (msg) {
        .toggle => handle_toggle(ui),
        .expand => handle_expand(ui),
        .collapse => handle_collapse(ui),
    };
}

fn handle_toggle(ui: *UiState) Cmd {
    ui.sidebar_collapsed = !ui.sidebar_collapsed;

    return .none;
}

fn handle_expand(ui: *UiState) Cmd {
    ui.sidebar_collapsed = false;

    return .none;
}

fn handle_collapse(ui: *UiState) Cmd {
    ui.sidebar_collapsed = true;

    return .none;
}
