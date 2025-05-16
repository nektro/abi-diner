const std = @import("std");
const shared = @import("./shared.zig");
const Tag = shared.Tag;

pub fn main() !void {
    var args = std.process.args();

    const argv0 = args.next().?;
    _ = argv0;

    const seed = try std.fmt.parseInt(u64, args.next().?, 10);
    var rand = std.Random.DefaultPrng.init(seed);
    const random = rand.random();

    const tag: Tag = @enumFromInt(try std.fmt.parseInt(u8, args.next().?, 10));

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    try writer.writeAll("extern fn do_test(a0: ");
    try Tag.renderType(tag, writer);
    try writer.writeAll(") void;\n\n");
    try writer.writeAll("export fn do_caller() void {\n");
    try writer.writeAll("    do_test(");
    try Tag.renderCast(tag, writer, random);
    try writer.writeAll(");\n");
    try writer.writeAll("}\n");
}
