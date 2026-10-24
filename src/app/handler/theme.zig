const message = @import("../message.zig");
const state = @import("../state.zig");
const intent = @import("../../core/window/intent.zig");

const Cmd = message.Cmd;
const IntentQueue = intent.IntentQueue;
const Model = state.Model;
const Theme = message.Theme;
const UiState = state.UiState;

pub fn handle(model: *Model, ui: *UiState, msg: Theme, intents: *IntentQueue) Cmd {
    _ = ui;
    _ = intents;

    return switch (msg) {
        .dark => handle_set_dark(model),
        .light => handle_set_light(model),
        .toggle => handle_toggle(model),
    };
}

fn handle_set_dark(model: *Model) Cmd {
    model.theme = .dark;

    return .none;
}

fn handle_set_light(model: *Model) Cmd {
    model.theme = .light;

    return .none;
}

fn handle_toggle(model: *Model) Cmd {
    model.theme = switch (model.theme) {
        .dark => .light,
        .light => .dark,
    };

    return .none;
}
