const std = @import("std");
const ubig = @import("root.zig").ubig;

pub fn rpn(allocator: std.mem.Allocator, src: []const u8) !ubig {
    var it = std.mem.tokenizeAny(u8, src, " \r\n\t");

    var stack: std.ArrayList(ubig) = .empty;

    defer stack.deinit(allocator);
    errdefer for (stack.items) |i| i.deinit();

    while (it.next()) |i| {
        if (i.len == 1 and !std.ascii.isDigit(i[0])) {
            // assume is operator
            switch (i[0]) {
                '+' => {
                    const b = stack.pop().?;
                    defer b.deinit();

                    var a = stack.pop().?;
                    try a.add(&b);

                    try stack.append(allocator, a);
                },
                '-' => {
                    const b = stack.pop().?;
                    defer b.deinit();

                    var a = stack.pop().?;
                    try a.subAssumeOrd(&b);

                    try stack.append(allocator, a);
                },
                '*' => {
                    const b = stack.pop().?;
                    defer b.deinit();

                    const a = stack.pop().?;
                    defer a.deinit();

                    const mul = try a.mul(&b);
                    try stack.append(allocator, mul);
                },
                '^' => {
                    const b = stack.pop().?;
                    defer b.deinit();

                    const a = stack.pop().?;
                    defer a.deinit();

                    const pow = try a.pow(&b);
                    try stack.append(allocator, pow);
                },
                else => return error.UnknownOperator,
            }

            continue;
        }

        // assume is number
        var acc: ubig = .init(allocator);
        errdefer acc.deinit();

        for (i) |d| {
            if (!std.ascii.isDigit(d)) return error.NotDigit;

            try acc.mulSd(10);
            try acc.addSd(d - '0');
        }

        try stack.append(allocator, acc);
    }

    if (stack.items.len != 1) return error.ExtraNumbers;

    const ret = stack.items[0];
    return ret;
}

test "rpn" {
    const allocator = std.testing.allocator;

    {
        const r = try rpn(allocator, "3 5 +");
        defer r.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{8}, r.digits.items);
    }

    {
        const r = try rpn(allocator, "3 5 *");
        defer r.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{15}, r.digits.items);
    }

    {
        const r = try rpn(allocator, "3 2 3 + *");
        defer r.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{15}, r.digits.items);
    }

    {
        const r = try rpn(allocator, "3 5 ^");
        defer r.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{243}, r.digits.items);
    }

    {
        const r = try rpn(allocator, "3 0 ^");
        defer r.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{1}, r.digits.items);
    }
}
