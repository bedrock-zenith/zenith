const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const server_module = b.addModule("zenith", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/zenith/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
    });

    const test_step = b.step("test", "Run tests");
    const mod_tests = b.addTest(.{
        .root_module = server_module,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    test_step.dependOn(&run_mod_tests.step);

    {
        // main executable
        const exe = b.addExecutable(.{
            .name = "zenith",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/executable/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zenith", .module = server_module },
                },
            }),
        });
        b.installArtifact(exe);
        const run_step = b.step("run", "Run the app");
        const run_cmd = b.addRunArtifact(exe);
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
            .name = "codegen",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/codegen/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{},
            }),
        });
        b.installArtifact(exe);
        const run_step = b.step("codegen", "Generate protocol and other resources");
        const run_cmd = b.addRunArtifact(exe);
        run_step.dependOn(&run_cmd.step);
        run_cmd.step.dependOn(b.getInstallStep());

        const exe_tests = b.addTest(.{
            .root_module = exe.root_module,
        });

        const run_exe_tests = b.addRunArtifact(exe_tests);
        test_step.dependOn(&run_exe_tests.step);
    }
}
