const message = @import("message.zig");
const state = @import("state.zig");
const handler = @import("handler.zig");
const intent = @import("../core/window/intent.zig");

const Cmd = message.Cmd;
const IntentQueue = intent.IntentQueue;
const Model = state.Model;
const Msg = message.Msg;
const UiState = state.UiState;

pub fn dispatch(model: *Model, ui: *UiState, msg: Msg, intents: *IntentQueue) Cmd {
    return switch (msg) {
        .app => |payload| handler.app.handle(model, ui, payload, intents),
        .navigation => |payload| handler.navigation.handle(model, ui, payload, intents),
        .sidebar => |payload| handler.sidebar.handle(model, ui, payload, intents),
        .theme => |payload| handler.theme.handle(model, ui, payload, intents),
        .window => |payload| handler.window.handle(model, ui, payload, intents),
        .workspace => |payload| handler.workspace.handle(model, ui, payload, intents),
    };
}
