const std = @import("std");
const shared = @import("./shared.zig");
const Tag = shared.Tag;
const FileWriter = std.fs.File.Writer;
const BufWriter = std.io.BufferedWriter(4096, FileWriter).Writer;

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
            var bw = std.io.bufferedWriter(stdout.writer());
            const writer = bw.writer();

            try writer.writeAll("#include <cstdint>\n");
            try writer.writeAll("#include <cstddef>\n");
            try writer.writeAll("\n");
            try writer.writeAll("#include \"cpp.h\"\n");
            try writer.writeAll("\n");
            try writer.writeAll("extern \"C\" void do_test(");
            try renderType(tag, writer);
            try writer.writeAll(");\n");
            try writer.writeAll("extern \"C\" void do_caller(void) {\n");
            try writer.writeAll("    ");
            try renderTypeBacker(tag, writer);
            try writer.writeAll(" v0 = (");
            try renderTypeBacker(tag, writer);
            try writer.writeAll(")");
            try renderValue(tag, writer, random);
            try writer.writeAll(";\n");
            try writer.writeAll("    do_test(*(");
            try renderType(tag, writer);
            try writer.writeAll("*)&v0);\n");
            try writer.writeAll("}\n");
            try bw.flush();
        },

        .callee => {
            const tag: Tag = @enumFromInt(try std.fmt.parseInt(u8, args.next().?, 10));

            const stdout = std.io.getStdOut();
            var bw = std.io.bufferedWriter(stdout.writer());
            const writer = bw.writer();

            try writer.writeAll("#include <cstdint>\n");
            try writer.writeAll("#include <cstddef>\n");
            try writer.writeAll("\n");
            try writer.writeAll("#include \"cpp.h\"\n");
            try writer.writeAll("\n");
            try writer.writeAll("extern \"C\" void do_panic();\n");
            try writer.writeAll("extern \"C\" void do_test(");
            try renderType(tag, writer);
            try writer.writeAll(" a0) {\n");
            try writer.writeAll("    ");
            try renderTypeBacker(tag, writer);
            try writer.writeAll(" v0 = (");
            try renderTypeBacker(tag, writer);
            try writer.writeAll(")");
            try renderValue(tag, writer, random);
            try writer.writeAll(";\n");
            try writer.writeAll("    if (a0 != *(");
            try renderType(tag, writer);
            try writer.writeAll("*)&v0) do_panic();\n");
            try writer.writeAll("}\n");
            try bw.flush();
        },
    }
}

pub fn supportsTag(tag: Tag) bool {
    return switch (tag) {
        .f128 => false, // type doesnt exist
        else => true,
    };
}

pub fn renderType(self: Tag, writer: BufWriter) !void {
    try writer.writeAll(switch (self) {
        .i8 => "int8_t",
        .i16 => "int16_t",
        .i32 => "int32_t",
        .i64 => "int64_t",
        .i128 => "int128_t",
        .u8 => "uint8_t",
        .u16 => "uint16_t",
        .u32 => "uint32_t",
        .u64 => "uint64_t",
        .u128 => "uint128_t",
        .f16 => "_Float16",
        .f32 => "float",
        .f64 => "double",
        .f128 => @panic("not stable"),
        .bool => "bool",
        .ptr => "void*",
    });
}

pub fn renderTypeBacker(self: Tag, writer: BufWriter) !void {
    try writer.writeAll(switch (self) {
        .u8, .i8 => "uint8_t",
        .u16, .i16 => "uint16_t",
        .u32, .i32 => "uint32_t",
        .u64, .i64 => "uint64_t",
        .u128, .i128 => "uint128_t",
        .f16 => "uint16_t",
        .f32 => "uint32_t",
        .f64 => "uint64_t",
        .f128 => "int128_t",
        .bool => "uint8_t",
        .ptr => "std::size_t",
    });
}

pub fn renderValue(self: Tag, writer: BufWriter, random: std.Random) !void {
    switch (self) {
        .u8, .i8 => try writer.print("{d}", .{random.int(u8)}),
        .u16, .i16 => try writer.print("{d}", .{random.int(u16)}),
        .u32, .i32 => try writer.print("{d}", .{random.int(u32)}),
        .u64, .i64 => try writer.print("{d}", .{random.int(u64)}),
        .u128, .i128 => try writer.print("{d}_u128", .{random.int(u128)}),
        .f16 => try writer.print("{d}", .{random.int(u16)}),
        .f32 => try writer.print("{d}", .{random.int(u32)}),
        .f64 => try writer.print("{d}", .{random.int(u64)}),
        .f128 => try writer.print("{d}", .{random.int(u128)}),
        .bool => try writer.print("{d}", .{random.int(u1)}),
        .ptr => try writer.print("{d}", .{random.int(usize)}),
    }
}
