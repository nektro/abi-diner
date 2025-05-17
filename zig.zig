const std = @import("std");
const shared = @import("./shared.zig");
const Tag = shared.Tag;

pub fn main() !void {
    var args = std.process.args();

    const argv0 = args.next().?;
    _ = argv0;

    switch (std.meta.stringToEnum(enum { caller, callee }, args.next().?).?) {
        .caller => {
            const seed = try std.fmt.parseInt(u64, args.next().?, 10);
            var rand = std.Random.DefaultPrng.init(seed);
            const random = rand.random();

            const tag: Tag = @enumFromInt(try std.fmt.parseInt(u8, args.next().?, 10));

            const stdout = std.io.getStdOut();
            const writer = stdout.writer();

            try writer.writeAll("extern fn do_test(a0: ");
            try renderType(tag, writer);
            try writer.writeAll(") void;\n\n");
            try writer.writeAll("export fn do_caller() void {\n");
            try writer.writeAll("    do_test(@as(");
            try renderType(tag, writer);
            try writer.writeAll(", ");
            try renderCast(tag, writer, random);
            try writer.writeAll("));\n");
            try writer.writeAll("}\n");
        },

        .callee => {
            const seed = try std.fmt.parseInt(u64, args.next().?, 10);
            var rand = std.Random.DefaultPrng.init(seed);
            const random = rand.random();

            const tag: Tag = @enumFromInt(try std.fmt.parseInt(u8, args.next().?, 10));

            const stdout = std.io.getStdOut();
            const writer = stdout.writer();

            try writer.writeAll("extern fn do_panic() void;\n");
            try writer.writeAll("export fn do_test(");
            try writer.writeAll("a0: ");
            try renderType(tag, writer);
            try writer.writeAll(") void {\n");
            try writer.writeAll("    if (a0 != @as(");
            try renderType(tag, writer);
            try writer.writeAll(", ");
            try renderCast(tag, writer, random);
            try writer.writeAll(")) do_panic();\n");
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

pub fn renderCast(self: Tag, writer: std.fs.File.Writer, random: std.Random) !void {
    switch (self) {
        .u8, .i8 => try writer.print("@bitCast(@as(u8, {d}))", .{random.int(u8)}),
        .u16, .i16 => try writer.print("@bitCast(@as(u16, {d}))", .{random.int(u16)}),
        .u32, .i32 => try writer.print("@bitCast(@as(u32, {d}))", .{random.int(u32)}),
        .u64, .i64 => try writer.print("@bitCast(@as(u64, {d}))", .{random.int(u64)}),
        .u128, .i128 => try writer.print("@bitCast(@as(u128, {d}))", .{random.int(u128)}),
        .f16 => try writer.print("@bitCast(@as(u16, {d}))", .{random.int(u16)}),
        .f32 => try writer.print("@bitCast(@as(u32, {d}))", .{random.int(u32)}),
        .f64 => try writer.print("@bitCast(@as(u64, {d}))", .{random.int(u64)}),
        .f128 => try writer.print("@bitCast(@as(u128, {d}))", .{random.int(u128)}),
        .bool => try writer.print("@bitCast(@as(u1, {d}))", .{random.int(u1)}),
        .ptr => try writer.print("@ptrFromInt({d})", .{random.int(usize)}),
    }
}
