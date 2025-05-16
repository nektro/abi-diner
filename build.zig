const std = @import("std");
const shared = @import("./shared.zig");
const Tag = shared.Tag;

pub fn build(b: *std.Build) void {
    const target = b.graph.host;

    const toolchain_zig: [2]*std.Build.Step.Compile = .{
        b.addExecutable(.{
            .name = "gen_zig_caller",
            .root_source_file = b.path("./gen_zig_caller.zig"),
            .target = target,
        }),
        b.addExecutable(.{
            .name = "gen_zig_callee",
            .root_source_file = b.path("./gen_zig_callee.zig"),
            .target = target,
        }),
    };

    const toolchains: []const [2]*std.Build.Step.Compile = &.{
        toolchain_zig,
    };

    const seed: u64 = @bitCast(std.time.microTimestamp());

    for (toolchains) |caller_toolchain| {
        for (std.enums.values(std.builtin.OptimizeMode)[0..1]) |caller_mode| {
            for (toolchains) |callee_toolchain| {
                for (std.enums.values(std.builtin.OptimizeMode)[0..1]) |callee_mode| {
                    for (std.enums.values(Tag)) |i| {
                        const exe = b.addExecutable(.{
                            .name = "test",
                            .root_source_file = b.path("./root.zig"),
                            .target = target,
                        });

                        {
                            const run_gen_caller = b.addRunArtifact(caller_toolchain[0]);
                            run_gen_caller.addArg(b.fmt("{d}", .{seed}));
                            run_gen_caller.addArg(b.fmt("{d}", .{@intFromEnum(i)}));

                            const obj = b.addObject(.{
                                .name = "caller",
                                .root_source_file = run_gen_caller.captureStdOut(),
                                .target = target,
                                .optimize = caller_mode,
                            });
                            exe.addObject(obj);
                        }

                        {
                            const run_gen_callee = b.addRunArtifact(callee_toolchain[1]);
                            run_gen_callee.addArg(b.fmt("{d}", .{seed}));
                            run_gen_callee.addArg(b.fmt("{d}", .{@intFromEnum(i)}));

                            const obj = b.addObject(.{
                                .name = "callee",
                                .root_source_file = run_gen_callee.captureStdOut(),
                                .target = target,
                                .optimize = callee_mode,
                            });
                            exe.addObject(obj);
                        }

                        const run = b.addRunArtifact(exe);

                        b.default_step.dependOn(&run.step);
                    }
                }
            }
        }
    }
}
