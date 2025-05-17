const std = @import("std");
const shared = @import("./shared.zig");
const Tag = shared.Tag;

pub fn build(b: *std.Build) void {
    const target = b.graph.host;
    const seed = b.option(u64, "seed", "") orelse std.crypto.random.int(u64);

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

    const toolchain_c: Toolchain = .{
        .lang = .c,
        .gen = b.addExecutable(.{
            .name = "gen_c",
            .root_source_file = b.path("./c.zig"),
            .target = target,
        }),
        .basename = "stdout.c",
    };
    _ = &toolchain_c;

    const toolchains: []const Toolchain = &.{
        toolchain_zig,
        toolchain_c,
    };

    std.log.warn("seed: {d}", .{seed});
    // 1747392854175661 crashes f32 @ 2144301497

    for (toolchains) |caller_toolchain| {
        for (std.enums.values(std.builtin.OptimizeMode)[0..1]) |caller_mode| {
            for (toolchains) |callee_toolchain| {
                for (std.enums.values(std.builtin.OptimizeMode)[0..1]) |callee_mode| {
                    for (std.enums.values(Tag)) |i| {
                        const is_zig = caller_toolchain.lang == .zig or callee_toolchain.lang == .zig;
                        _ = &is_zig;
                        const is_c = caller_toolchain.lang == .c or callee_toolchain.lang == .c;
                        _ = &is_c;

                        if (is_c and i == .f16) continue;
                        if (is_c and i == .f128) continue;
                        if ((is_c and is_zig) and (i == .u128 or i == .i128)) continue;

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

                            addObject(exe, caller_toolchain, b, "caller", run_gen_caller, target, caller_mode);
                        }

                        {
                            const run_gen_callee = b.addRunArtifact(callee_toolchain.gen);
                            run_gen_callee.addArg("callee");
                            run_gen_callee.addArg(b.fmt("{d}", .{seed}));
                            run_gen_callee.addArg(b.fmt("{d}", .{@intFromEnum(i)}));

                            addObject(exe, callee_toolchain, b, "callee", run_gen_callee, target, callee_mode);
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
        c,
    };
};

fn addObject(exe: *std.Build.Step.Compile, toolchain: Toolchain, b: *std.Build, name: []const u8, run_gen: *std.Build.Step.Run, target: std.Build.ResolvedTarget, mode: std.builtin.OptimizeMode) void {
    switch (toolchain.lang) {
        .zig => {
            const obj = b.addObject(.{
                .name = name,
                .root_source_file = run_gen.captureStdOut(),
                .target = target,
                .optimize = mode,
            });
            run_gen.captured_stdout.?.basename = toolchain.basename;
            exe.addObject(obj);
        },
        .c => {
            const obj = b.addObject(.{
                .name = name,
                .root_source_file = null,
                .target = target,
                .optimize = mode,
            });
            obj.addCSourceFile(.{ .file = run_gen.captureStdOut() });
            obj.linkLibC();
            run_gen.captured_stdout.?.basename = toolchain.basename;
            exe.addObject(obj);
        },
    }
}
