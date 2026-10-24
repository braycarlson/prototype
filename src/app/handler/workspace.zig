const message = @import("../message.zig");
const state = @import("../state.zig");
const intent = @import("../../core/window/intent.zig");

const Cmd = message.Cmd;
const IntentQueue = intent.IntentQueue;
const Model = state.Model;
const UiState = state.UiState;
const WorkspaceAction = message.WorkspaceAction;

const FLASH_CLEAR_DELAY_FRAMES = 10;
const UNCLOAK_DELAY_FRAMES = 3;

pub fn handle(model: *Model, ui: *UiState, msg: WorkspaceAction, intents: *IntentQueue) Cmd {
    _ = ui;

    return switch (msg) {
        .switch_to => |index| handle_switch_to(model, index, intents),
        .create => handle_create(model),
        .destroy => |index| handle_destroy(model, index, intents),
        .move_window => |payload| handle_move_window(model, payload, intents),
        .clear_flashes => handle_clear_flashes(model, intents),
        .uncloak_active => handle_uncloak_active(model, intents),
    };
}

fn handle_switch_to(model: *Model, index: usize, intents: *IntentQueue) Cmd {
    model.workspace_manager.switch_to(index, intents);
    model.refresh_window_list();

    return .{ .schedule = .{
        .msg = .{ .workspace = .uncloak_active },
        .frames_remaining = UNCLOAK_DELAY_FRAMES,
    } };
}

fn handle_create(model: *Model) Cmd {
    _ = model.workspace_manager.create() catch return .none;

    return .none;
}

fn handle_destroy(model: *Model, index: usize, intents: *IntentQueue) Cmd {
    model.workspace_manager.destroy(index, intents);
    model.refresh_window_list();

    return .{ .schedule = .{
        .msg = .{ .workspace = .uncloak_active },
        .frames_remaining = UNCLOAK_DELAY_FRAMES,
    } };
}

fn handle_move_window(
    model: *Model,
    payload: message.MoveWindowPayload,
    intents: *IntentQueue,
) Cmd {
    model.workspace_manager.move_window(payload.handle, payload.target_index, intents);
    model.refresh_window_list();

    return .none;
}

fn handle_clear_flashes(model: *Model, intents: *IntentQueue) Cmd {
    model.workspace_manager.clear_flashes(intents);

    return .none;
}

fn handle_uncloak_active(model: *Model, intents: *IntentQueue) Cmd {
    model.workspace_manager.uncloak_pending(intents);

    return .{ .schedule = .{
        .msg = .{ .workspace = .clear_flashes },
        .frames_remaining = FLASH_CLEAR_DELAY_FRAMES,
    } };
}
