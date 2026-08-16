const std = @import("std");

pub fn build(b: *std.Build) void {
    var exit_code: u8 = undefined;
    const commit = b.runAllowFail(
        &.{ "git", "rev-parse", "--short", "HEAD" },
        &exit_code,
        .ignore,
    ) catch "unknown";

    const version = b.option(
        []const u8,
        "version",
        "Version string to embed in the binary",
    ) orelse std.mem.trim(u8, commit, " \t\r\n");

    const options = b.addOptions();

    options.addOption([]const u8, "version", version);

    const options_module = options.createModule();

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "resgr",

        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),

            .target = target,
            .optimize = optimize,

            .single_threaded = true,
            .strip = true,
            .unwind_tables = .none,

            .imports = &.{.{
                .name = "build_options",
                .module = options_module,
            }},
        }),
    });

    exe.link_data_sections = true;
    exe.link_function_sections = true;
    exe.link_gc_sections = true;
    exe.link_z_relro = false;

    if (optimize != .Debug and target.result.os.tag != std.Target.Os.Tag.macos) exe.lto = .full;

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const exe_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),

            .target = target,
            .optimize = optimize,

            .single_threaded = true,

            .imports = &.{.{
                .name = "build_options",
                .module = options_module,
            }},
        }),
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");

    test_step.dependOn(&run_exe_tests.step);
}
