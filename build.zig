const std = @import("std");

fn module(comptime name: []const u8, b: *std.Build, target: std.Build.ResolvedTarget, test_step: *std.Build.Step) *std.Build.Module {
    const m = b.addModule(name, .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/" ++ name ++ "/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
    });

    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = m })).step);

    return m;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run tests");
    const zenith = module("zenith", b, target, test_step);
    const web_rtc = module("web-rtc", b, target, test_step);

    {
        // main executable
        const exe = b.addExecutable(.{
            .name = "zenith",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/executable/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zenith", .module = zenith },
                    .{ .name = "web-rtc", .module = web_rtc },
                },
            }),
        });
        b.installArtifact(exe);
        const run_step = b.step("run", "Run the app");
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.addPassthruArgs();
        run_step.dependOn(&run_cmd.step);
        run_cmd.step.dependOn(b.getInstallStep());

        const exe_tests = b.addTest(.{
            .root_module = exe.root_module,
        });

        const run_exe_tests = b.addRunArtifact(exe_tests);
        test_step.dependOn(&run_exe_tests.step);
    }

    {
        // main codegen executable
        const exe = b.addExecutable(.{
            .name = "meta-gen",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/meta/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{},
            }),
        });
        b.installArtifact(exe);
        const run_step = b.step("generate", "Generate protocol and other resources");
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.addPassthruArgs();

        run_step.dependOn(&run_cmd.step);

        run_cmd.step.dependOn(b.getInstallStep());

        const exe_tests = b.addTest(.{
            .root_module = exe.root_module,
        });

        const run_exe_tests = b.addRunArtifact(exe_tests);
        test_step.dependOn(&run_exe_tests.step);
    }
}
