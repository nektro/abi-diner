extern fn do_caller() void;

pub fn main() void {
    do_caller();
}

export fn do_panic() void {
    @panic("reached unreachable code");
}
