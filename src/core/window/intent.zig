pub const INTENTS_MAX: usize = 256;

pub const Rect = struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

pub const RestoreMode = enum {
    normal,
    maximized,
    minimized,
};

pub const RestorePayload = struct {
    handle: isize,
    mode: RestoreMode,
    rect: Rect,
};

pub const BatchRaisePayload = struct {
    handles: [*]const isize,
    count: usize,
    focus_handle: isize,
};

pub const UncloakPayload = struct {
    handle: isize,
    remove_layered: bool,
};

pub const WindowIntent = union(enum) {
    minimize: isize,
    restore_quiet: RestorePayload,
    restore_active: RestorePayload,
    focus: isize,
    stop_flash: isize,
    focus_self,
    raise: isize,
    batch_raise: BatchRaisePayload,
    cloak: isize,
    uncloak: UncloakPayload,
};

pub const IntentQueue = struct {
    buffer: [INTENTS_MAX]WindowIntent = undefined,
    len: usize = 0,

    pub fn append(self: *IntentQueue, item: WindowIntent) void {
        if (self.len >= INTENTS_MAX) return;

        self.buffer[self.len] = item;
        self.len += 1;
    }

    pub fn slice(self: *const IntentQueue) []const WindowIntent {
        return self.buffer[0..self.len];
    }

    pub fn reset(self: *IntentQueue) void {
        self.len = 0;
    }
};
