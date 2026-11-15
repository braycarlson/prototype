const std = @import("std");
const win32 = @import("win32.zig");

const assert = std.debug.assert;

const GetComputerNameExW = win32.GetComputerNameExW;

const MEMORYSTATUSEX = win32.MEMORYSTATUSEX;
const GlobalMemoryStatusEx = win32.GlobalMemoryStatusEx;

pub const SystemInfo = struct {
    hostname: [256]u8,
    hostname_length: usize,
    memory_mb_total: u64,
    memory_mb_available: u64,
    memory_percent_load: u32,

    pub fn query() SystemInfo {
        var result = SystemInfo{
            .hostname = undefined,
            .hostname_length = 0,
            .memory_mb_total = 0,
            .memory_mb_available = 0,
            .memory_percent_load = 0,
        };

        result.query_hostname();
        result.query_memory();

        assert(result.hostname_length > 0);
        assert(result.hostname_length <= result.hostname.len);

        return result;
    }

    fn query_hostname(self: *SystemInfo) void {
        var buffer: [256]u16 = undefined;
        var size: u32 = buffer.len;

        const success = GetComputerNameExW(.DnsHostname, @ptrCast(&buffer), &size);

        if (success == 0) {
            const fallback = "Unknown";

            @memcpy(self.hostname[0..fallback.len], fallback);
            self.hostname_length = fallback.len;
        } else {
            assert(size <= buffer.len);

            var i: usize = 0;

            while (i < size) : (i += 1) {
                self.hostname[i] = if (buffer[i] <= 0x7F)
                    @truncate(buffer[i])
                else
                    '?';
            }

            self.hostname_length = i;
        }

        assert(self.hostname_length <= self.hostname.len);
    }

    fn query_memory(self: *SystemInfo) void {
        var status: MEMORYSTATUSEX = undefined;
        status.dwLength = @sizeOf(MEMORYSTATUSEX);

        const success = GlobalMemoryStatusEx(&status);

        if (success != 0) {
            self.memory_mb_total = status.ullTotalPhys / (1024 * 1024);
            self.memory_mb_available = status.ullAvailPhys / (1024 * 1024);
            self.memory_percent_load = status.dwMemoryLoad;

            assert(self.memory_mb_available <= self.memory_mb_total);
            assert(self.memory_percent_load <= 100);
        }
    }

    pub fn hostname_slice(self: *const SystemInfo) []const u8 {
        return self.hostname[0..self.hostname_length];
    }

    pub fn memory_mb_used(self: *const SystemInfo) u64 {
        assert(self.memory_mb_total >= self.memory_mb_available);

        return self.memory_mb_total - self.memory_mb_available;
    }
};
