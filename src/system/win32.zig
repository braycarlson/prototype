const std = @import("std");

const assert = std.debug.assert;

pub const BOOL = i32;
pub const COLORREF = u32;
pub const HDWP = isize;
pub const HINSTANCE = *opaque {};
pub const HRESULT = i32;
pub const HWND = *opaque {};
pub const HWINEVENTHOOK = *opaque {};
pub const LPARAM = isize;
pub const LRESULT = isize;
pub const WPARAM = usize;

pub const S_OK: HRESULT = 0;
pub const EVENT_OBJECT_CREATE: u32 = 32768;
pub const EVENT_OBJECT_DESTROY: u32 = 32769;
pub const EVENT_OBJECT_SHOW: u32 = 32770;

pub const POINT = extern struct {
    x: i32,
    y: i32,
};

pub const RECT = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: u32,
    wParam: WPARAM,
    lParam: LPARAM,
    time: u32,
    pt: POINT,
};

pub const FLASHWINFO_FLAGS = packed struct(u32) {
    CAPTION: u1 = 0,
    TRAY: u1 = 0,
    TIMER: u1 = 0,
    _: u29 = 0,
};

pub const FLASHW_STOP = FLASHWINFO_FLAGS{};

pub const FLASHWINFO = extern struct {
    cbSize: u32,
    hwnd: ?HWND,
    dwFlags: FLASHWINFO_FLAGS,
    uCount: u32,
    dwTimeout: u32,
};

pub const LAYERED_WINDOW_ATTRIBUTES_FLAGS = packed struct(u32) {
    COLORKEY: u1 = 0,
    ALPHA: u1 = 0,
    _: u30 = 0,
};

pub const SET_WINDOW_POS_FLAGS = packed struct(u32) {
    NOSIZE: u1 = 0,
    NOMOVE: u1 = 0,
    NOZORDER: u1 = 0,
    NOREDRAW: u1 = 0,
    NOACTIVATE: u1 = 0,
    DRAWFRAME: u1 = 0,
    SHOWWINDOW: u1 = 0,
    HIDEWINDOW: u1 = 0,
    NOCOPYBITS: u1 = 0,
    NOOWNERZORDER: u1 = 0,
    NOSENDCHANGING: u1 = 0,
    _: u21 = 0,
};

pub const WINDOWPLACEMENT_FLAGS = packed struct(u32) {
    SETMINPOSITION: u1 = 0,
    RESTORETOMAXIMIZED: u1 = 0,
    ASYNCWINDOWPLACEMENT: u1 = 0,
    _: u29 = 0,
};

pub const SHOW_WINDOW_CMD = enum(u32) {
    HIDE = 0,
    SHOWNORMAL = 1,
    SHOWMINIMIZED = 2,
    SHOWMAXIMIZED = 3,
    SHOWNOACTIVATE = 4,
    SHOW = 5,
    MINIMIZE = 6,
    SHOWMINNOACTIVE = 7,
    SHOWNA = 8,
    RESTORE = 9,
    SHOWDEFAULT = 10,
    FORCEMINIMIZE = 11,
};

pub const SW_MINIMIZE = SHOW_WINDOW_CMD.MINIMIZE;
pub const SW_RESTORE = SHOW_WINDOW_CMD.RESTORE;
pub const SW_SHOWMAXIMIZED = SHOW_WINDOW_CMD.SHOWMAXIMIZED;
pub const SW_SHOWMINNOACTIVE = SHOW_WINDOW_CMD.SHOWMINNOACTIVE;
pub const SW_SHOWNOACTIVATE = SHOW_WINDOW_CMD.SHOWNOACTIVATE;

pub const WINDOWPLACEMENT = extern struct {
    length: u32,
    flags: WINDOWPLACEMENT_FLAGS,
    showCmd: SHOW_WINDOW_CMD,
    ptMinPosition: POINT,
    ptMaxPosition: POINT,
    rcNormalPosition: RECT,
};

pub const GET_WINDOW_CMD = enum(u32) {
    HWNDFIRST = 0,
    HWNDLAST = 1,
    HWNDNEXT = 2,
    HWNDPREV = 3,
    OWNER = 4,
    CHILD = 5,
    ENABLEDPOPUP = 6,
};

pub const GW_OWNER = GET_WINDOW_CMD.OWNER;

pub const WINDOW_LONG_PTR_INDEX = enum(i32) {
    _EXSTYLE = -20,
    _STYLE = -16,
};

pub const GWL_EXSTYLE = WINDOW_LONG_PTR_INDEX._EXSTYLE;
pub const GWL_STYLE = WINDOW_LONG_PTR_INDEX._STYLE;

pub const DWMWINDOWATTRIBUTE = enum(u32) {
    _,
};

pub const COMPUTER_NAME_FORMAT = enum(i32) {
    NetBIOS = 0,
    DnsHostname = 1,
    DnsDomain = 2,
    DnsFullyQualified = 3,
    PhysicalNetBIOS = 4,
    PhysicalDnsHostname = 5,
    PhysicalDnsDomain = 6,
    PhysicalDnsFullyQualified = 7,
    Max = 8,
};

pub const MEMORYSTATUSEX = extern struct {
    dwLength: u32,
    dwMemoryLoad: u32,
    ullTotalPhys: u64,
    ullAvailPhys: u64,
    ullTotalPageFile: u64,
    ullAvailPageFile: u64,
    ullTotalVirtual: u64,
    ullAvailVirtual: u64,
    ullAvailExtendedVirtual: u64,
};

pub const OSVERSIONINFOW = extern struct {
    dwOSVersionInfoSize: u32,
    dwMajorVersion: u32,
    dwMinorVersion: u32,
    dwBuildNumber: u32,
    dwPlatformId: u32,
    szCSDVersion: [128]u16,
};

pub const WNDENUMPROC = *const fn (
    param0: HWND,
    param1: LPARAM,
) callconv(.winapi) BOOL;

pub const WINEVENTPROC = *const fn (
    hWinEventHook: ?HWINEVENTHOOK,
    event: u32,
    hwnd: ?HWND,
    idObject: i32,
    idChild: i32,
    idEventThread: u32,
    dwmsEventTime: u32,
) callconv(.winapi) void;

pub extern "user32" fn BeginDeferWindowPos(
    window_count: i32,
) callconv(.winapi) HDWP;

pub extern "user32" fn DeferWindowPos(
    hWinPosInfo: HDWP,
    hWnd: ?HWND,
    hWndInsertAfter: ?HWND,
    x: i32,
    y: i32,
    cx: i32,
    cy: i32,
    uFlags: SET_WINDOW_POS_FLAGS,
) callconv(.winapi) HDWP;

pub extern "user32" fn DispatchMessageW(
    lpMsg: ?*const MSG,
) callconv(.winapi) LRESULT;

pub extern "user32" fn EndDeferWindowPos(
    hWinPosInfo: HDWP,
) callconv(.winapi) BOOL;

pub extern "user32" fn EnumWindows(
    lpEnumFunc: ?WNDENUMPROC,
    lParam: LPARAM,
) callconv(.winapi) BOOL;

pub extern "user32" fn FindWindowW(
    lpClassName: ?[*:0]const u16,
    lpWindowName: ?[*:0]const u16,
) callconv(.winapi) ?HWND;

pub extern "user32" fn FlashWindowEx(
    pfwi: ?*FLASHWINFO,
) callconv(.winapi) BOOL;

pub extern "user32" fn GetClassNameW(
    hWnd: ?HWND,
    lpClassName: [*:0]u16,
    count_max: i32,
) callconv(.winapi) i32;

pub extern "user32" fn GetMessageW(
    lpMsg: ?*MSG,
    hWnd: ?HWND,
    wMsgFilterMin: u32,
    wMsgFilterMax: u32,
) callconv(.winapi) BOOL;

pub extern "user32" fn GetWindow(
    hWnd: ?HWND,
    uCmd: GET_WINDOW_CMD,
) callconv(.winapi) ?HWND;

pub extern "user32" fn GetWindowLongW(
    hWnd: ?HWND,
    index: WINDOW_LONG_PTR_INDEX,
) callconv(.winapi) i32;

pub extern "user32" fn GetWindowPlacement(
    hWnd: ?HWND,
    lpwndpl: ?*WINDOWPLACEMENT,
) callconv(.winapi) BOOL;

pub extern "user32" fn GetWindowRect(
    hWnd: ?HWND,
    lpRect: ?*RECT,
) callconv(.winapi) BOOL;

pub extern "user32" fn GetWindowTextW(
    hWnd: ?HWND,
    lpString: [*:0]u16,
    count_max: i32,
) callconv(.winapi) i32;

pub extern "user32" fn IsIconic(
    hWnd: ?HWND,
) callconv(.winapi) BOOL;

pub extern "user32" fn IsWindow(
    hWnd: ?HWND,
) callconv(.winapi) BOOL;

pub extern "user32" fn IsWindowVisible(
    hWnd: ?HWND,
) callconv(.winapi) BOOL;

pub extern "user32" fn IsZoomed(
    hWnd: ?HWND,
) callconv(.winapi) BOOL;

pub extern "user32" fn SetForegroundWindow(
    hWnd: ?HWND,
) callconv(.winapi) BOOL;

pub extern "user32" fn SetLayeredWindowAttributes(
    hwnd: ?HWND,
    crKey: COLORREF,
    bAlpha: u8,
    dwFlags: LAYERED_WINDOW_ATTRIBUTES_FLAGS,
) callconv(.winapi) BOOL;

pub extern "user32" fn SetWindowLongW(
    hWnd: ?HWND,
    index: WINDOW_LONG_PTR_INDEX,
    dwNewLong: i32,
) callconv(.winapi) i32;

pub extern "user32" fn SetWindowPlacement(
    hWnd: ?HWND,
    lpwndpl: ?*const WINDOWPLACEMENT,
) callconv(.winapi) BOOL;

pub extern "user32" fn SetWindowPos(
    hWnd: ?HWND,
    hWndInsertAfter: ?HWND,
    X: i32,
    Y: i32,
    cx: i32,
    cy: i32,
    uFlags: SET_WINDOW_POS_FLAGS,
) callconv(.winapi) BOOL;

pub extern "user32" fn SetWinEventHook(
    eventMin: u32,
    eventMax: u32,
    hmodWinEventProc: ?HINSTANCE,
    pfnWinEventProc: ?WINEVENTPROC,
    idProcess: u32,
    idThread: u32,
    dwFlags: u32,
) callconv(.winapi) ?HWINEVENTHOOK;

pub extern "user32" fn ShowWindow(
    hWnd: ?HWND,
    show_command: SHOW_WINDOW_CMD,
) callconv(.winapi) BOOL;

pub extern "user32" fn TranslateMessage(
    lpMsg: ?*const MSG,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn GetComputerNameExW(
    NameType: COMPUTER_NAME_FORMAT,
    lpBuffer: ?[*:0]u16,
    size: ?*u32,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn GetVersionExW(
    lpVersionInformation: ?*OSVERSIONINFOW,
) callconv(.winapi) BOOL;

pub extern "kernel32" fn GlobalMemoryStatusEx(
    lpBuffer: ?*MEMORYSTATUSEX,
) callconv(.winapi) BOOL;

pub extern "dwmapi" fn DwmGetWindowAttribute(
    hwnd: ?HWND,
    dwAttribute: DWMWINDOWATTRIBUTE,
    pvAttribute: ?*anyopaque,
    cbAttribute: u32,
) callconv(.winapi) HRESULT;

pub extern "dwmapi" fn DwmSetWindowAttribute(
    hwnd: ?HWND,
    dwAttribute: DWMWINDOWATTRIBUTE,
    pvAttribute: ?*const anyopaque,
    cbAttribute: u32,
) callconv(.winapi) HRESULT;

comptime {
    assert(@sizeOf(SET_WINDOW_POS_FLAGS) == @sizeOf(u32));
    assert(@sizeOf(LAYERED_WINDOW_ATTRIBUTES_FLAGS) == @sizeOf(u32));
    assert(@sizeOf(FLASHWINFO_FLAGS) == @sizeOf(u32));
    assert(@sizeOf(WINDOWPLACEMENT_FLAGS) == @sizeOf(u32));
}
