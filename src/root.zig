const std = @import("std");

pub const ubig = @import("bigint/ubig.zig").ubig;

test {
    std.testing.refAllDeclsRecursive(@This());
}
