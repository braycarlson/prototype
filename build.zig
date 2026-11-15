const std = @import("std");

const assert = std.debug.assert;

const format_paths = [_][]const u8{ "build.zig", "src" };
const windows_query = std.Target.Query{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu };

const Steps = struct {
    check: *std.Build.Step,
    ci: *std.Build.Step,
    run: *std.Build.Step,
    test_all: *std.Build.Step,
    test_fmt: *std.Build.Step,
    test_unit: *std.Build.Step,
    test_windows: *std.Build.Step,
};

const Context = struct {
    builder: *std.Build,
    filters: []const []const u8,
    optimize: std.lang.Optimize,
    steps: Steps,
    target: std.Build.ResolvedTarget,
};

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const filters = builder.option(
        []const []const u8,
        "test-filter",
        "Skip tests that do not match any filter",
    ) orelse &.{};

    const windows = if (target.result.os.tag == .windows)
        target
    else
        builder.resolveTargetQuery(windows_query);

    const context = Context{
        .builder = builder,
        .filters = filters,
        .optimize = optimize,
        .steps = .{
            .check = builder.step("check", "Compile every artifact without running it"),
            .ci = builder.step("ci", "Run every check and test"),
            .run = builder.step("run", "Build and run the application"),
            .test_all = builder.step("test", "Run every test suite and the format check"),
            .test_fmt = builder.step("test:fmt", "Check that every source file is formatted"),
            .test_unit = builder.step("test:unit", "Run the unit tests and the tidy check"),
            .test_windows = builder.step("test:windows", "Run the Windows tests on a Windows host"),
        },
        .target = windows,
    };

    add_executable(context);
    add_unit_tests(context);
    add_windows_tests(context);
    add_format(context);

    builder.getInstallStep().dependOn(context.steps.check);
}

fn add_executable(context: Context) void {
    assert(context.target.result.os.tag == .windows);

    const builder = context.builder;
    const dvui = window_dependency(context);
    const module = create_module(context, "src/main.zig", context.target);
    const exe = builder.addExecutable(.{ .name = "prototype", .root_module = module });

    module.addImport("dvui", dvui.module("dvui_dx11"));
    dvui.module("dvui_dx11").addImport("dvui_app", module);

    exe.subsystem = .windows;

    builder.installArtifact(exe);

    const run = builder.addRunArtifact(exe);

    run.step.dependOn(builder.getInstallStep());

    context.steps.run.dependOn(&run.step);
    context.steps.check.dependOn(&exe.step);
}

fn add_unit_tests(context: Context) void {
    const builder = context.builder;
    const module = create_module(context, "src/unit_tests.zig", builder.graph.host);
    const unit = builder.addTest(.{ .root_module = module, .filters = context.filters });
    const run = builder.addRunArtifact(unit);

    run.has_side_effects = true;
    run.setCwd(builder.path("."));

    context.steps.test_unit.dependOn(&run.step);
    context.steps.test_all.dependOn(&run.step);
    context.steps.check.dependOn(&unit.step);
    context.steps.ci.dependOn(context.steps.test_unit);
}

fn add_windows_tests(context: Context) void {
    assert(context.target.result.os.tag == .windows);

    const builder = context.builder;
    const module = create_module(context, "src/windows_tests.zig", context.target);
    const suite = builder.addTest(.{ .root_module = module, .filters = context.filters });

    context.steps.check.dependOn(&suite.step);
    context.steps.ci.dependOn(context.steps.test_windows);

    if (builder.graph.host.result.os.tag != .windows) {
        return;
    }

    const run = builder.addRunArtifact(suite);

    run.has_side_effects = true;
    run.setCwd(builder.path("."));

    context.steps.test_windows.dependOn(&run.step);
    context.steps.test_all.dependOn(&run.step);
}

fn add_format(context: Context) void {
    const builder = context.builder;
    const format = builder.addFmt(.{ .paths = builder.pathList(&format_paths), .check = true });

    context.steps.test_fmt.dependOn(&format.step);
    context.steps.test_all.dependOn(&format.step);
    context.steps.ci.dependOn(context.steps.test_fmt);
    context.steps.ci.dependOn(context.steps.check);
}

fn create_module(
    context: Context,
    root: []const u8,
    target: std.Build.ResolvedTarget,
) *std.Build.Module {
    assert(std.mem.startsWith(u8, root, "src/"));
    assert(std.mem.endsWith(u8, root, ".zig"));

    const builder = context.builder;

    const nimble = builder.dependency("nimble", .{
        .target = target,
        .optimize = context.optimize,
    });

    const module = builder.createModule(.{
        .root_source_file = builder.path(root),
        .target = target,
        .optimize = context.optimize,
        .link_libc = true,
    });

    module.addImport("nimble", nimble.module("nimble"));

    return module;
}

fn window_dependency(context: Context) *std.Build.Dependency {
    assert(context.target.result.os.tag == .windows);

    return context.builder.dependency("dvui", .{
        .target = context.target,
        .optimize = context.optimize,
        .backend = .dx11,
    });
}
