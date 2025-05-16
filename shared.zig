const std = @import("std");

pub const Tag = enum(u8) {
    i8,
    i16,
    i32,
    i64,
    i128,
    u8,
    u16,
    u32,
    u64,
    u128,
    f16,
    f32,
    f64,
    f128,
    bool,
    ptr,
};
