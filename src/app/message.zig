const MESSAGES_PENDING_MAX = 64;
const COMMANDS_BATCH_MAX = 16;

pub const MsgQueue = struct {
    buffer: [MESSAGES_PENDING_MAX]Msg = undefined,
    len: usize = 0,

    pub fn append(self: *MsgQueue, msg: Msg) void {
        if (self.len >= MESSAGES_PENDING_MAX) return;

        self.buffer[self.len] = msg;
        self.len += 1;
    }

    pub fn slice(self: *const MsgQueue) []const Msg {
        return self.buffer[0..self.len];
    }

    pub fn reset(self: *MsgQueue) void {
        self.len = 0;
    }
};

pub const Msg = union(enum) {
    app: App,
    navigation: Navigation,
    sidebar: Sidebar,
    theme: Theme,
    window: Window,
    workspace: WorkspaceAction,
};

pub const App = enum {
    initialized,
    refresh_system_info,
    refresh_window_list,
};

pub const Navigation = enum {
    home,
    windows,
    workspaces,
    settings,
};

pub const Sidebar = enum {
    toggle,
    expand,
    collapse,
};

pub const Theme = enum {
    dark,
    light,
    toggle,
};

pub const Window = enum {
    about_opened,
    about_closed,
    options_opened,
    options_closed,
};

pub const WorkspaceAction = union(enum) {
    switch_to: usize,
    create,
    destroy: usize,
    move_window: MoveWindowPayload,
    clear_flashes,
    uncloak_active,
};

pub const MoveWindowPayload = struct {
    handle: isize,
    target_index: usize,
};

pub const ScheduledMsg = struct {
    msg: Msg,
    frames_remaining: u32,
};

pub const SCHEDULED_MAX = 8;

pub const Cmd = union(enum) {
    none,
    batch: []const Cmd,
    schedule: ScheduledMsg,
};

pub const CmdBuilder = struct {
    commands: [COMMANDS_BATCH_MAX]Cmd = undefined,
    len: usize = 0,

    pub fn init() CmdBuilder {
        return .{};
    }

    pub fn add(self: *CmdBuilder, cmd: Cmd) *CmdBuilder {
        switch (cmd) {
            .none => {},
            .batch => unreachable,
            .schedule => {
                if (self.len >= COMMANDS_BATCH_MAX) return self;

                self.commands[self.len] = cmd;
                self.len += 1;
            },
        }

        return self;
    }

    pub fn build(self: *CmdBuilder) Cmd {
        if (self.len == 0) return .none;
        if (self.len == 1) return self.commands[0];
        return .{ .batch = self.commands[0..self.len] };
    }
};
