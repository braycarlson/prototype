const std = @import("std");
const dvui = @import("dvui");

const dispatcher = @import("app/dispatcher.zig");
const message = @import("app/message.zig");
const state = @import("app/state.zig");
const view = @import("ui/view.zig");

const intent = @import("core/window/intent.zig");
const window_service = @import("core/window/service.zig");

const hook = @import("system/hook.zig");
const workspace = @import("system/workspace.zig");

const assert = std.debug.assert;

const Cmd = message.Cmd;
const IntentQueue = intent.IntentQueue;
const Model = state.Model;
const Msg = message.Msg;
const MsgQueue = message.MsgQueue;
const ScheduledMsg = message.ScheduledMsg;
const UiState = state.UiState;

var model: Model = undefined;
var ui_state: UiState = undefined;
var queue: MsgQueue = .{};
var intents: IntentQueue = .{};
var initialized: bool = false;

var scheduled: [message.SCHEDULED_MAX]ScheduledMsg = undefined;
var scheduled_count: usize = 0;

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 1000.0, .h = 700.0 },
            .min_size = .{ .w = 400.0, .h = 300.0 },
            .org = "braycarlson",
            .app = "prototype",
            .title = "Prototype UI",
        },
    },
    .initFn = app_init,
    .deinitFn = app_deinit,
    .frameFn = app_frame,
};

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;

pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};

pub fn app_init(win: *dvui.Window) !void {
    model = Model.init();
    ui_state = UiState.init();
    queue = .{};
    intents = .{};
    scheduled_count = 0;

    win.themeSet(dvui.Theme.builtin.adwaita_dark);

    hook.install();

    enqueue(.{ .app = .initialized });
    initialized = true;

    assert(model.page == .home);
    assert(model.theme == .dark);
    assert(model.workspace_manager.count == 1);
    assert(model.workspace_manager.active_index == 0);
    assert(hook.is_installed());
}

pub fn app_deinit(_: *dvui.Window) void {
    if (initialized) {
        model.deinit();
    }
}

pub fn app_frame() !dvui.App.Result {
    assert(initialized);

    tick_scheduled();
    process_hook_events();
    process_messages();
    view.render(&model, &ui_state, &queue);

    return .ok;
}

fn tick_scheduled() void {
    var i: usize = 0;

    while (i < scheduled_count) {
        if (scheduled[i].frames_remaining == 0) {
            enqueue(scheduled[i].msg);
            scheduled[i] = scheduled[scheduled_count - 1];
            scheduled_count -= 1;
        } else {
            scheduled[i].frames_remaining -= 1;
            i += 1;
        }
    }
}

fn process_hook_events() void {
    var events: [hook.EVENTS_PENDING_MAX]hook.HookEvent = undefined;
    const count = hook.drain(&events);

    var i: usize = 0;

    while (i < count) : (i += 1) {
        apply_hook_event(events[i]);
    }
}

fn apply_hook_event(event: hook.HookEvent) void {
    if (model.workspace_manager.switching) return;

    switch (event.kind) {
        .window_shown => {
            if (model.workspace_manager.is_tracked(event.handle)) return;
            if (!workspace.is_trackable_window(event.handle)) return;

            _ = model.workspace_manager.active_mut().try_add(event.handle);
        },
        .window_destroyed => {
            model.workspace_manager.remove_everywhere(event.handle);
        },
    }
}

fn process_messages() void {
    const pending = queue.slice();

    for (pending) |msg| {
        const cmd = dispatcher.dispatch(&model, &ui_state, msg, &intents);

        window_service.execute(&intents);
        intents.reset();
        execute_command(cmd);
    }

    queue.reset();
}

fn execute_command(cmd: Cmd) void {
    switch (cmd) {
        .none => {},
        .batch => |commands| {
            for (commands) |command| {
                switch (command) {
                    .none => {},
                    .batch => unreachable,
                    .schedule => |s| schedule(s),
                }
            }
        },
        .schedule => |s| schedule(s),
    }
}

fn schedule(s: ScheduledMsg) void {
    if (scheduled_count >= message.SCHEDULED_MAX) return;

    scheduled[scheduled_count] = s;
    scheduled_count += 1;
}

fn enqueue(msg: Msg) void {
    queue.append(msg);
}
