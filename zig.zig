const std = @import("std");
const shared = @import("./shared.zig");
const Tag = shared.Tag;

pub fn main() !void {
    var args = std.process.args();
    defer std.debug.assert(args.next() == null);

    const argv0 = args.next().?;
    _ = argv0;

    const seed = try std.fmt.parseInt(u64, args.next().?, 10);
    var rand = std.Random.DefaultPrng.init(seed);
    const random = rand.random();

    const count = try std.fmt.parseInt(u8, args.next().?, 10);
    std.debug.assert(count == 1);

    switch (std.meta.stringToEnum(enum { caller, callee }, args.next().?).?) {
        .caller => {
            const tag: Tag = @enumFromInt(try std.fmt.parseInt(u8, args.next().?, 10));

            const stdout = std.io.getStdOut();
            const writer = stdout.writer();

            try writer.writeAll("extern fn do_test(a0: ");
            try renderType(tag, writer);
            try writer.writeAll(") void;\n");
            try writer.writeAll("export fn do_caller() void {\n");
            try writer.writeAll("    do_test(");
            try renderValue(tag, writer, random);
            try writer.writeAll(");\n");
            try writer.writeAll("}\n");
        },

        .callee => {
            const tag: Tag = @enumFromInt(try std.fmt.parseInt(u8, args.next().?, 10));

            const stdout = std.io.getStdOut();
            const writer = stdout.writer();

            try writer.writeAll("extern fn do_panic() void;\n");
            try writer.writeAll("export fn do_test(");
            try writer.writeAll("a0: ");
            try renderType(tag, writer);
            try writer.writeAll(") void {\n");
            try writer.writeAll("    if (a0 != ");
            try renderValue(tag, writer, random);
            try writer.writeAll(") do_panic();\n");
            try writer.writeAll("}\n");
        },
    }
}

pub fn renderType(self: Tag, writer: std.fs.File.Writer) !void {
    try writer.writeAll(switch (self) {
        .i8 => "i8",
        .i16 => "i16",
        .i32 => "i32",
        .i64 => "i64",
        .i128 => "i128",
        .u8 => "u8",
        .u16 => "u16",
        .u32 => "u32",
        .u64 => "u64",
        .u128 => "u128",
        .f16 => "f16",
        .f32 => "f32",
        .f64 => "f64",
        .f128 => "f128",
        .bool => "bool",
        .ptr => "*anyopaque",
    });
}

pub fn renderValue(self: Tag, writer: std.fs.File.Writer, random: std.Random) !void {
    switch (self) {
        .i8 => try writer.print("@as(i8, @bitCast(@as(u8, {d})))", .{random.int(u8)}),
        .i16 => try writer.print("@as(i16, @bitCast(@as(u16, {d})))", .{random.int(u16)}),
        .i32 => try writer.print("@as(i32, @bitCast(@as(u32, {d})))", .{random.int(u32)}),
        .i64 => try writer.print("@as(i64, @bitCast(@as(u64, {d})))", .{random.int(u64)}),
        .i128 => try writer.print("@as(i128, @bitCast(@as(u128, {d})))", .{random.int(u128)}),
        .u8 => try writer.print("@as(u8, @bitCast(@as(u8, {d})))", .{random.int(u8)}),
        .u16 => try writer.print("@as(u16, @bitCast(@as(u16, {d})))", .{random.int(u16)}),
        .u32 => try writer.print("@as(u32, @bitCast(@as(u32, {d})))", .{random.int(u32)}),
        .u64 => try writer.print("@as(u64, @bitCast(@as(u64, {d})))", .{random.int(u64)}),
        .u128 => try writer.print("@as(u128, @bitCast(@as(u128, {d})))", .{random.int(u128)}),
        .f16 => try writer.print("@as(f16, @bitCast(@as(u16, {d})))", .{random.int(u16)}),
        .f32 => try writer.print("@as(f32, @bitCast(@as(u32, {d})))", .{random.int(u32)}),
        .f64 => try writer.print("@as(f64, @bitCast(@as(u64, {d})))", .{random.int(u64)}),
        .f128 => try writer.print("@as(f128, @bitCast(@as(u128, {d})))", .{random.int(u128)}),
        .bool => try writer.print("@as(bool, @bitCast(@as(u1, {d})))", .{random.int(u1)}),
        .ptr => try writer.print("@as(*anyopaque, @ptrFromInt({d}))", .{random.int(usize)}),
    }
}
