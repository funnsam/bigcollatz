const std = @import("std");

const ubig = @import("bigcollatz").ubig;
const counters = @import("counters.zig");

pub fn solve(_num: ubig) !void {
    var num = _num;
    defer num.deinit();

    const prefactor_count = num.ctz();
    counters.even += prefactor_count;
    num.rsh(prefactor_count);

    while (!std.mem.eql(ubig.Digit, num.digits.items, &.{1})) {
        counters.odd += 1;
        try num.mulAddSd(3, 1);

        const rep = num.ctz();
        counters.even += rep;
        num.rsh(rep);
    }
}
