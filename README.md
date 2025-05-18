# abi-diner

![loc](https://sloc.xyz/github/nektro/abi-diner)
[![license](https://img.shields.io/github/license/nektro/abi-diner.svg)](https://github.com/nektro/abi-diner/blob/master/LICENSE)

Verify the ABI of pairs of compilers.

Inspired by https://github.com/Gankra/abi-cafe but leveraging the Zig Build System.

## Built With

- Zig 0.14.0

## Supported Languages

- [Zig](https://ziglang.org/)
- [C](https://clang.llvm.org/)
- [C++](https://clang.llvm.org/)

## How It Works

3 files get compiled together in roughly this form:

```zig
extern fn do_caller() void;

pub fn main() void {
    do_caller();
}

export fn do_panic() void {
    @panic("reached unreachable code");
}
```

```zig
extern fn do_test(a0: f16) void;
export fn do_caller() void {
    do_test(@as(f16, @bitCast(@as(u16, 64776))));
}
```

```zig
extern fn do_panic() void;
export fn do_test(a0: f16) void {
    if (a0 != @as(f16, @bitCast(@as(u16, 64776)))) do_panic();
}
```

the key part being that the latter two files are generated in various configurations of types, argument count, and language.

## License

MIT
