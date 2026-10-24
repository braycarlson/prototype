const message = @import("../message.zig");
const state = @import("../state.zig");
const intent = @import("../../core/window/intent.zig");

const Cmd = message.Cmd;
const IntentQueue = intent.IntentQueue;
const Model = state.Model;
const UiState = state.UiState;
const Window = message.Window;

pub fn handle(model: *Model, ui: *UiState, msg: Window, intents: *IntentQueue) Cmd {
    _ = model;
    _ = intents;

    return switch (msg) {
        .about_opened => handle_about_opened(ui),
        .about_closed => handle_about_closed(ui),
        .options_opened => handle_options_opened(ui),
        .options_closed => handle_options_closed(ui),
    };
}

fn handle_about_opened(ui: *UiState) Cmd {
    ui.about_show = true;

    return .none;
}

fn handle_about_closed(ui: *UiState) Cmd {
    ui.about_show = false;

    return .none;
}

fn handle_options_opened(ui: *UiState) Cmd {
    ui.options_show = true;

    return .none;
}

fn handle_options_closed(ui: *UiState) Cmd {
    ui.options_show = false;

    return .none;
}
