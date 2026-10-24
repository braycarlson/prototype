const std = @import("std");

const format_paths = [_][]const u8{ "build.zig", "src" };

const Steps = struct {
    check: *std.Build.Step,
    ci: *std.Build.Step,
    run: *std.Build.Step,
    test_all: *std.Build.Step,
    test_fmt: *std.Build.Step,
    test_unit: *std.Build.Step,
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
        },
        .target = target,
    };

    add_executable(context);
    add_unit_tests(context);
    add_cross_check(context);
    add_format(context);

    builder.getInstallStep().dependOn(context.steps.check);
}

fn add_executable(context: Context) void {
    const builder = context.builder;
    const module = create_module(context);

    const dvui = builder.dependency("dvui", .{
        .target = context.target,
        .optimize = context.optimize,
        .backend = .dx11,
    });

    const exe = builder.addExecutable(.{
        .name = "prototype",
        .root_module = module,
    });

    dvui.module("dvui_dx11").addImport("dvui_app", module);

    set_subsystem(context, exe);

    builder.installArtifact(exe);

    const run = builder.addRunArtifact(exe);

    run.step.dependOn(builder.getInstallStep());

    context.steps.run.dependOn(&run.step);
    context.steps.check.dependOn(&exe.step);
}

fn add_unit_tests(context: Context) void {
    const builder = context.builder;
    const module = create_module_from(context, "src/unit_tests.zig");

    const unit = builder.addTest(.{
        .root_module = module,
        .filters = context.filters,
    });

    const run = builder.addRunArtifact(unit);

    run.setCwd(builder.path("."));

    context.steps.test_unit.dependOn(&run.step);
    context.steps.test_all.dependOn(&run.step);
    context.steps.check.dependOn(&unit.step);
    context.steps.ci.dependOn(context.steps.test_unit);
}

fn set_subsystem(context: Context, exe: *std.Build.Step.Compile) void {
    if (context.target.result.os.tag != .windows) {
        return;
    }

    exe.subsystem = .windows;
}

fn add_cross_check(context: Context) void {
    const builder = context.builder;

    const queries = [_]std.Target.Query{
        .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    };

    for (queries) |query| {
        const resolved = builder.resolveTargetQuery(query);

        var scoped = context;

        scoped.target = resolved;

        const module = create_module(scoped);

        const dvui = builder.dependency("dvui", .{
            .target = scoped.target,
            .optimize = scoped.optimize,
            .backend = .dx11,
        });

        const exe = builder.addExecutable(.{
            .name = builder.fmt("prototype-{s}", .{@tagName(query.abi.?)}),
            .root_module = module,
        });

        dvui.module("dvui_dx11").addImport("dvui_app", module);

        set_subsystem(scoped, exe);

        context.steps.ci.dependOn(&exe.step);
    }
}

fn add_format(context: Context) void {
    const builder = context.builder;

    const format = builder.addFmt(.{
        .paths = builder.pathList(&format_paths),
        .check = true,
    });

    context.steps.test_fmt.dependOn(&format.step);
    context.steps.test_all.dependOn(&format.step);
    context.steps.ci.dependOn(context.steps.test_fmt);
    context.steps.ci.dependOn(context.steps.check);
}

fn create_module(context: Context) *std.Build.Module {
    const result = create_module_from(context, "src/main.zig");
    return result;
}

fn create_module_from(context: Context, root: []const u8) *std.Build.Module {
    const builder = context.builder;

    const dvui = builder.dependency("dvui", .{
        .target = context.target,
        .optimize = context.optimize,
        .backend = .dx11,
    });

    const nimble = builder.dependency("nimble", .{
        .target = context.target,
        .optimize = context.optimize,
    });

    const module = builder.createModule(.{
        .root_source_file = builder.path(root),
        .target = context.target,
        .optimize = context.optimize,
        .link_libc = true,
    });

    module.addImport("dvui", dvui.module("dvui_dx11"));
    module.addImport("nimble", nimble.module("nimble"));

    return module;
}
