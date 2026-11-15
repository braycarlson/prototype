const std = @import("std");

const dispatcher = @import("app/dispatcher.zig");
const view = @import("ui.zig").view;

const intent = @import("core.zig").window.intent;
const window_service = @import("core.zig").window.service;

const hook_module = @import("system.zig").hook;
const win32 = @import("system.zig").win32;
const workspace = @import("system.zig").workspace;

pub const message = @import("app/message.zig");
pub const state = @import("app/state.zig");

const assert = std.debug.assert;

const Cmd = message.Cmd;
const Hook = hook_module.Hook;
const HookEvent = hook_module.HookEvent;
const IntentQueue = intent.IntentQueue;
const Model = state.Model;
const Msg = message.Msg;
const MsgQueue = message.MsgQueue;
const ScheduledMsg = message.ScheduledMsg;
const UiState = state.UiState;

hook: Hook,
intents: IntentQueue,
model: Model,
queue: MsgQueue,
scheduled: [message.SCHEDULED_MAX]ScheduledMsg,
scheduled_count: usize,
ui_state: UiState,

const App = @This();

pub fn init(app: *App, procedure: win32.WINEVENTPROC) void {
    app.intents = .{};
    app.model = Model.init();
    app.queue = .{};
    app.scheduled = undefined;
    app.scheduled_count = 0;
    app.ui_state = UiState.init();

    app.hook.init(procedure);
    app.enqueue(.{ .app = .initialized });

    assert(app.model.page == .home);
    assert(app.model.theme == .dark);
    assert(app.model.workspace_manager.count == 1);
    assert(app.model.workspace_manager.active_index == 0);
    assert(app.hook.is_installed());
}

pub fn deinit(app: *App) void {
    assert(app.hook.is_installed());
    assert(app.scheduled_count <= message.SCHEDULED_MAX);

    app.hook.deinit();
    app.model.deinit();

    app.* = undefined;
}

pub fn frame(app: *App) void {
    assert(app.hook.is_installed());
    assert(app.scheduled_count <= message.SCHEDULED_MAX);

    app.tick_scheduled();
    app.process_hook_events();
    app.process_messages();
    view.render(&app.model, &app.ui_state, &app.queue);
}

fn tick_scheduled(app: *App) void {
    var i: usize = 0;

    while (i < app.scheduled_count) {
        if (app.scheduled[i].frames_remaining == 0) {
            app.enqueue(app.scheduled[i].msg);
            app.scheduled[i] = app.scheduled[app.scheduled_count - 1];
            app.scheduled_count -= 1;
        } else {
            app.scheduled[i].frames_remaining -= 1;
            i += 1;
        }
    }
}

fn process_hook_events(app: *App) void {
    var events: [hook_module.EVENTS_PENDING_MAX]HookEvent = undefined;
    const count = app.hook.drain(&events);

    var i: usize = 0;

    while (i < count) : (i += 1) {
        app.apply_hook_event(events[i]);
    }
}

fn apply_hook_event(app: *App, event: HookEvent) void {
    assert(event.handle != 0);

    if (app.model.workspace_manager.switching) return;

    switch (event.kind) {
        .window_shown => {
            if (app.model.workspace_manager.is_tracked(event.handle)) return;
            if (!workspace.is_trackable_window(event.handle)) return;

            _ = app.model.workspace_manager.active_mut().try_add(event.handle);
        },
        .window_destroyed => {
            app.model.workspace_manager.remove_everywhere(event.handle);
        },
    }
}

fn process_messages(app: *App) void {
    const pending = app.queue.slice();

    for (pending) |msg| {
        const cmd = dispatcher.dispatch(&app.model, &app.ui_state, msg, &app.intents);

        window_service.execute(&app.intents);
        app.intents.reset();
        app.execute_command(cmd);
    }

    app.queue.reset();
}

fn execute_command(app: *App, cmd: Cmd) void {
    switch (cmd) {
        .none => {},
        .batch => |commands| {
            for (commands) |command| {
                switch (command) {
                    .none => {},
                    .batch => unreachable,
                    .schedule => |s| app.schedule(s),
                }
            }
        },
        .schedule => |s| app.schedule(s),
    }
}

fn schedule(app: *App, s: ScheduledMsg) void {
    if (app.scheduled_count >= message.SCHEDULED_MAX) return;

    app.scheduled[app.scheduled_count] = s;
    app.scheduled_count += 1;
}

fn enqueue(app: *App, msg: Msg) void {
    app.queue.append(msg);
}
