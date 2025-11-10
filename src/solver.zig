// split off a part of the bigint to solve, and bulk update it when the divided part is about to
// overflow by keeping track of operations and update by (mul*num + add) >> rsh
//
// this saves a lot(!!) of processing time by having to update the bigint less

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
        try solveSmall(num.digits.items[0] & small_chunk_mask).apply(&num);
    }
}

const small_chunk_size = @typeInfo(usize).int.bits / 2;
const small_chunk_mask = (1 << small_chunk_size) - 1;

const Update = struct {
    mul: usize = 1,
    add: usize = 0,
    rsh: u6 = 0,

    fn apply(self: @This(), num: *ubig) !void {
        try num.mulAddSd(self.mul, self.add);

        const ctz = num.ctz();
        num.rsh(ctz);
        counters.even += ctz;
    }
};

fn solveSmall(_num: usize) Update {
    var num: usize = _num;
    var update: Update = .{};

    while (num != 1 and update.rsh < small_chunk_size) {
        num = num * 3 + 1;

        update.mul *= 3;
        update.add = update.add * 3 + (@as(usize, 1) << update.rsh);
        counters.odd += 1;

        const trail = @min(small_chunk_size - update.rsh, @ctz(num));
        num >>= @intCast(trail);
        update.rsh += @intCast(trail);
    }

    return update;
}
