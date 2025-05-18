const std = @import("std");
const shared = @import("./shared.zig");
const Tag = shared.Tag;

pub fn StackLinkedListNode(comptime T: type) type {
    return struct {
        data: *const T,
        next: ?*const @This() = null,
    };
}
const ArgList = StackLinkedListNode(Tag);

pub fn build(b: *std.Build) void {
    const target = b.graph.host;
    const random = b.option(bool, "random", "") orelse false;
    const seed = if (random) std.crypto.random.int(u64) else b.option(u64, "seed", "") orelse 10335101430366274186;

    const cZig = b.option(bool, "cZig", "") orelse false;
    const cC = b.option(bool, "cC", "") orelse false;
    const cCpp = b.option(bool, "cCpp", "") orelse false;
    const cRust = b.option(bool, "cRust", "") orelse false;
    const cAll = b.option(bool, "cAll", "") orelse false;

    const oDebug = b.option(bool, "oDebug", "") orelse false;
    const oReleaseSafe = b.option(bool, "oReleaseSafe", "") orelse false;
    const oReleaseFast = b.option(bool, "oReleaseFast", "") orelse false;
    const oReleaseSmall = b.option(bool, "oReleaseSmall", "") orelse false;
    const oAll = b.option(bool, "oAll", "") orelse false;

    const toolchain_zig: Toolchain = .{
        .lang = .zig,
        .gen = b.addExecutable(.{
            .name = "gen_zig",
            .root_source_file = b.path("./zig.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
        .basename = "stdout.zig",
        .supportsTag = @import("./zig.zig").supportsTag,
    };
    _ = &toolchain_zig;

    const toolchain_c: Toolchain = .{
        .lang = .c,
        .gen = b.addExecutable(.{
            .name = "gen_c",
            .root_source_file = b.path("./c.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
        .basename = "stdout.c",
        .supportsTag = @import("./c.zig").supportsTag,
    };
    _ = &toolchain_c;

    const toolchain_cpp: Toolchain = .{
        .lang = .cpp,
        .gen = b.addExecutable(.{
            .name = "gen_cpp",
            .root_source_file = b.path("./cpp.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
        .basename = "stdout.cpp",
        .supportsTag = @import("./cpp.zig").supportsTag,
    };
    _ = &toolchain_cpp;

    const toolchain_rust: Toolchain = .{
        .lang = .rust,
        .gen = b.addExecutable(.{
            .name = "gen_rust",
            .root_source_file = b.path("./rust.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        }),
        .basename = "stdout.rs",
        .supportsTag = @import("./rust.zig").supportsTag,
    };
    _ = &toolchain_rust;

    const toolchains_all = [_]Toolchain{
        toolchain_zig,
        toolchain_c,
        toolchain_cpp,
        toolchain_rust,
    };

    var toolchains = std.BoundedArray(Toolchain, toolchains_all.len){};
    if (cZig) toolchains.appendAssumeCapacity(toolchain_zig);
    if (cC) toolchains.appendAssumeCapacity(toolchain_c);
    if (cCpp) toolchains.appendAssumeCapacity(toolchain_cpp);
    if (cRust) toolchains.appendAssumeCapacity(toolchain_rust);
    if (cAll) toolchains.appendSliceAssumeCapacity(&toolchains_all);

    var modes = std.BoundedArray(std.builtin.OptimizeMode, 4){};
    if (oDebug) modes.appendAssumeCapacity(.Debug);
    if (oReleaseSafe) modes.appendAssumeCapacity(.ReleaseSafe);
    if (oReleaseFast) modes.appendAssumeCapacity(.ReleaseFast);
    if (oReleaseSmall) modes.appendAssumeCapacity(.ReleaseSmall);
    if (oAll) modes.appendSliceAssumeCapacity(std.enums.values(std.builtin.OptimizeMode));

    std.log.warn("seed: {d}", .{seed});
    // 1747392854175661 crashes f32 @ 2144301497
    // 1747435010791578 crashes f16 @ 64776 (NaN)

    const main_obj = b.addObject(.{
        .name = "main.o",
        .root_source_file = b.path("./root.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    main_obj.linkLibC();

    for (toolchains.slice()) |caller_toolchain| {
        for (modes.slice()) |caller_mode| {
            for (toolchains.slice()) |callee_toolchain| {
                for (modes.slice()) |callee_mode| {
                    const is_zig = caller_toolchain.lang == .zig or callee_toolchain.lang == .zig;
                    _ = &is_zig;
                    const is_c = caller_toolchain.lang == .c or callee_toolchain.lang == .c;
                    _ = &is_c;
                    const is_cpp = caller_toolchain.lang == .cpp or callee_toolchain.lang == .cpp;
                    _ = &is_cpp;
                    const is_rust = caller_toolchain.lang == .rust or callee_toolchain.lang == .rust;
                    _ = &is_rust;

                    for (std.enums.values(Tag)) |i| {
                        if (!caller_toolchain.supportsTag(i)) continue;
                        if (!callee_toolchain.supportsTag(i)) continue;
                        if ((is_c and is_zig) and (i == .u128 or i == .i128)) continue;
                        if ((is_c and is_cpp) and (i == .u128 or i == .i128)) continue;
                        if ((is_c and is_rust) and (i == .u128 or i == .i128)) continue;

                        const exe = b.addExecutable(.{
                            .name = b.fmt("test__{s}_{s}__{s}_{s}", .{ @tagName(caller_toolchain.lang), @tagName(caller_mode), @tagName(callee_toolchain.lang), @tagName(callee_mode) }),
                            .root_source_file = null,
                            .target = target,
                        });
                        exe.addObject(main_obj);

                        {
                            const run_gen_caller = b.addRunArtifact(caller_toolchain.gen);
                            run_gen_caller.addArg(b.fmt("{d}", .{seed}));
                            run_gen_caller.addArg("1");
                            run_gen_caller.addArg("caller");
                            run_gen_caller.addArg(b.fmt("{d}", .{@intFromEnum(i)}));

                            addObject(exe, caller_toolchain, b, "caller.o", run_gen_caller, target, caller_mode);
                        }

                        {
                            const run_gen_callee = b.addRunArtifact(callee_toolchain.gen);
                            run_gen_callee.addArg(b.fmt("{d}", .{seed}));
                            run_gen_callee.addArg("1");
                            run_gen_callee.addArg("callee");
                            run_gen_callee.addArg(b.fmt("{d}", .{@intFromEnum(i)}));

                            addObject(exe, callee_toolchain, b, "callee.o", run_gen_callee, target, callee_mode);
                        }

                        const run = b.addRunArtifact(exe);

                        b.default_step.dependOn(&run.step);

                        var arg_list_head = ArgList{ .data = &i };
                        genCombo(1, 2, b, target, seed, main_obj, caller_toolchain, caller_mode, callee_toolchain, callee_mode, &arg_list_head, &arg_list_head);
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
    supportsTag: *const fn (Tag) bool,

    const Lang = enum {
        zig,
        c,
        cpp,
        rust,
    };
};

fn genCombo(
    depth: u32,
    max_depth: u32,
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    seed: u64,
    main_obj: *std.Build.Step.Compile,
    caller_toolchain: Toolchain,
    caller_mode: std.builtin.OptimizeMode,
    callee_toolchain: Toolchain,
    callee_mode: std.builtin.OptimizeMode,
    arg_list_head: *ArgList,
    arg_list_tail: *ArgList,
) void {
    if (depth >= max_depth) return;

    const is_zig = caller_toolchain.lang == .zig or callee_toolchain.lang == .zig;
    _ = &is_zig;
    const is_c = caller_toolchain.lang == .c or callee_toolchain.lang == .c;
    _ = &is_c;
    const is_cpp = caller_toolchain.lang == .cpp or callee_toolchain.lang == .cpp;
    _ = &is_cpp;
    const is_rust = caller_toolchain.lang == .rust or callee_toolchain.lang == .rust;
    _ = &is_rust;

    for (std.enums.values(Tag)) |i| {
        if (!caller_toolchain.supportsTag(i)) continue;
        if (!callee_toolchain.supportsTag(i)) continue;

        if ((is_c and is_zig) and (i == .u128 or i == .i128)) continue;
        if ((is_c and is_cpp) and (i == .u128 or i == .i128)) continue;
        if ((is_c and is_rust) and (i == .u128 or i == .i128)) continue;

        var arg_list_next = ArgList{ .data = &i };
        arg_list_tail.next = &arg_list_next;
        genTest(b, target, seed, main_obj, caller_toolchain, caller_mode, callee_toolchain, callee_mode, depth + 1, arg_list_head);

        genCombo(depth + 1, max_depth, b, target, seed, main_obj, caller_toolchain, caller_mode, callee_toolchain, callee_mode, arg_list_head, &arg_list_next);
    }
}

fn genTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    seed: u64,
    main_obj: *std.Build.Step.Compile,
    caller_toolchain: Toolchain,
    caller_mode: std.builtin.OptimizeMode,
    callee_toolchain: Toolchain,
    callee_mode: std.builtin.OptimizeMode,
    depth: u32,
    arg_list_head: *ArgList,
) void {
    const exe = b.addExecutable(.{
        .name = b.fmt("test__{s}_{s}__{s}_{s}", .{ @tagName(caller_toolchain.lang), @tagName(caller_mode), @tagName(callee_toolchain.lang), @tagName(callee_mode) }),
        .root_source_file = null,
        .target = target,
    });
    exe.addObject(main_obj);

    {
        const run_gen_caller = b.addRunArtifact(caller_toolchain.gen);
        run_gen_caller.addArg(b.fmt("{d}", .{seed}));
        run_gen_caller.addArg(b.fmt("{d}", .{depth}));
        run_gen_caller.addArg("caller");
        addArgs(run_gen_caller, b, arg_list_head);

        addObject(exe, caller_toolchain, b, "caller.o", run_gen_caller, target, caller_mode);
    }

    {
        const run_gen_callee = b.addRunArtifact(callee_toolchain.gen);
        run_gen_callee.addArg(b.fmt("{d}", .{seed}));
        run_gen_callee.addArg(b.fmt("{d}", .{depth}));
        run_gen_callee.addArg("callee");
        addArgs(run_gen_callee, b, arg_list_head);

        addObject(exe, callee_toolchain, b, "callee.o", run_gen_callee, target, callee_mode);
    }

    const run = b.addRunArtifact(exe);

    b.default_step.dependOn(&run.step);
}

fn addArgs(
    exe: *std.Build.Step.Run,
    b: *std.Build,
    arg_list: *const ArgList,
) void {
    var item: ?*const ArgList = arg_list;
    while (item) |cur| : (item = cur.next) {
        exe.addArg(b.fmt("{d}", .{@intFromEnum(cur.data.*)}));
    }
}

fn addObject(exe: *std.Build.Step.Compile, toolchain: Toolchain, b: *std.Build, name: []const u8, run_gen: *std.Build.Step.Run, target: std.Build.ResolvedTarget, mode: std.builtin.OptimizeMode) void {
    switch (toolchain.lang) {
        .zig => {
            const obj = b.addObject(.{
                .name = name,
                .root_source_file = run_gen.captureStdOut(),
                .target = target,
                .optimize = mode,
            });
            obj.linkLibC();
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
        .cpp => {
            const obj = b.addObject(.{
                .name = name,
                .root_source_file = null,
                .target = target,
                .optimize = mode,
            });
            obj.addCSourceFile(.{ .file = run_gen.captureStdOut() });
            obj.addIncludePath(b.path("./include"));
            obj.linkLibCpp();
            run_gen.captured_stdout.?.basename = toolchain.basename;
            exe.addObject(obj);
        },
        .rust => {
            const cmd = b.addSystemCommand(&.{"rustc"});
            cmd.addArgs(&.{ "--emit", "obj" });
            cmd.addArg("-lc");
            cmd.addArg("-g");
            switch (mode) {
                .Debug => cmd.addArgs(&.{ "-C", "opt-level=0", "-C", "debug-assertions=y" }),
                .ReleaseSafe => cmd.addArgs(&.{ "-C", "opt-level=3", "-C", "debug-assertions=y" }),
                .ReleaseSmall => cmd.addArgs(&.{ "-C", "opt-level=s", "-C", "debug-assertions=n" }),
                .ReleaseFast => cmd.addArgs(&.{ "-C", "opt-level=3", "-C", "debug-assertions=n" }),
            }
            cmd.addArg("-o");
            const output = cmd.addOutputFileArg(name);
            cmd.addFileArg(run_gen.captureStdOut());
            run_gen.captured_stdout.?.basename = toolchain.basename;
            exe.addObjectFile(output);
        },
    }
}
