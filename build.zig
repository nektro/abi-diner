const std = @import("std");
const shared = @import("./shared.zig");
const Tag = shared.Tag;

pub fn build(b: *std.Build) void {
    const target = b.graph.host;

    const toolchain_zig: Toolchain = .{
        .lang = .zig,
        .gen = b.addExecutable(.{
            .name = "gen_zig",
            .root_source_file = b.path("./zig.zig"),
            .target = target,
        }),
        .basename = "stdout.zig",
    };
    _ = &toolchain_zig;

    const toolchains: []const Toolchain = &.{
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
                            const run_gen_caller = b.addRunArtifact(caller_toolchain.gen);
                            run_gen_caller.addArg("caller");
                            run_gen_caller.addArg(b.fmt("{d}", .{seed}));
                            run_gen_caller.addArg(b.fmt("{d}", .{@intFromEnum(i)}));

                            exe.addObject(objFrom(caller_toolchain, b, "caller", run_gen_caller, target, caller_mode));
                        }

                        {
                            const run_gen_callee = b.addRunArtifact(callee_toolchain.gen);
                            run_gen_callee.addArg("callee");
                            run_gen_callee.addArg(b.fmt("{d}", .{seed}));
                            run_gen_callee.addArg(b.fmt("{d}", .{@intFromEnum(i)}));

                            exe.addObject(objFrom(callee_toolchain, b, "callee", run_gen_callee, target, callee_mode));
                        }

                        const run = b.addRunArtifact(exe);

                        b.default_step.dependOn(&run.step);
                    }
                }
            }
        }
    }
}

const Toolchain = struct {
    lang: Lang,
    gen: *std.Build.Step.Compile,
    basename: []const u8,

    const Lang = enum {
        zig,
    };
};

fn objFrom(toolchain: Toolchain, b: *std.Build, name: []const u8, run_gen: *std.Build.Step.Run, target: std.Build.ResolvedTarget, mode: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    switch (toolchain.lang) {
        .zig => {
            const obj = b.addObject(.{
                .name = name,
                .root_source_file = run_gen.captureStdOut(),
                .target = target,
                .optimize = mode,
            });
            run_gen.captured_stdout.?.basename = toolchain.basename;
            return obj;
        },
    }
}
