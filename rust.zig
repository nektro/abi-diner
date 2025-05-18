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

            try writer.writeAll("#![no_main]\n");
            try writer.writeAll("#![allow(improper_ctypes)]\n");
            try writer.writeAll("\n");
            try writer.writeAll("extern \"C\" {\n");
            try writer.writeAll("    fn do_test(a0: ");
            try renderType(tag, writer);
            try writer.writeAll(");\n");
            try writer.writeAll("}\n");
            try writer.writeAll("\n");
            try writer.writeAll("#[no_mangle]\n");
            try writer.writeAll("pub extern \"C\" fn do_caller() {\n");
            try writer.writeAll("    unsafe { do_test(");
            try renderValue(tag, writer, random);
            try writer.writeAll("); }\n");
            try writer.writeAll("}\n");
        },

        .callee => {
            const seed = try std.fmt.parseInt(u64, args.next().?, 10);
            var rand = std.Random.DefaultPrng.init(seed);
            const random = rand.random();

            const tag: Tag = @enumFromInt(try std.fmt.parseInt(u8, args.next().?, 10));

            const stdout = std.io.getStdOut();
            const writer = stdout.writer();

            try writer.writeAll("#![no_main]\n");
            try writer.writeAll("#![allow(unused_parens)]\n");
            try writer.writeAll("#![allow(improper_ctypes_definitions)]\n");
            try writer.writeAll("\n");
            try writer.writeAll("extern \"C\" {\n");
            try writer.writeAll("    fn do_panic();\n");
            try writer.writeAll("}\n");
            try writer.writeAll("\n");
            try writer.writeAll("#[no_mangle]\n");
            try writer.writeAll("pub extern \"C\" fn do_test(a0: ");
            try renderType(tag, writer);
            try writer.writeAll(") {\n");
            try writer.writeAll("    unsafe { if (a0 != (");
            try renderValue(tag, writer, random);
            try writer.writeAll(")) { do_panic(); } }\n");
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
        .ptr => "*const ()",
    });
}

pub fn renderValue(self: Tag, writer: std.fs.File.Writer, random: std.Random) !void {
    switch (self) {
        .i8 => try writer.print("std::mem::transmute::<u8, i8>({d}u8)", .{random.int(u8)}),
        .i16 => try writer.print("std::mem::transmute::<u16, i16>({d}u16)", .{random.int(u16)}),
        .i32 => try writer.print("std::mem::transmute::<u32, i32>({d}u32)", .{random.int(u32)}),
        .i64 => try writer.print("std::mem::transmute::<u64, i64>({d}u64)", .{random.int(u64)}),
        .i128 => try writer.print("std::mem::transmute::<u128, i128>({d}u128)", .{random.int(u128)}),
        .u8 => try writer.print("{d}u8", .{random.int(u8)}),
        .u16 => try writer.print("{d}u16", .{random.int(u16)}),
        .u32 => try writer.print("{d}u32", .{random.int(u32)}),
        .u64 => try writer.print("{d}u64", .{random.int(u64)}),
        .u128 => try writer.print("{d}u128", .{random.int(u128)}),
        .f16 => try writer.print("f16::from_bits({d}u16)", .{random.int(u16)}),
        .f32 => try writer.print("f32::from_bits({d}u32)", .{random.int(u32)}),
        .f64 => try writer.print("f64::from_bits({d}u64)", .{random.int(u64)}),
        .f128 => try writer.print("f128::from_bits({d}u128)", .{random.int(u128)}),
        .bool => try writer.print("{d}u8 != 0", .{random.int(u1)}),
        .ptr => try writer.print("{d}usize as *const ()", .{random.int(usize)}),
    }
}
