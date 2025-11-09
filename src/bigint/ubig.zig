const std = @import("std");
const umath = @import("umath.zig");

pub const ubig = struct {
    pub const Digit = usize;
    pub const DoubleDigit = std.meta.Int(.unsigned, bits * 2);

    pub const bits = @typeInfo(Digit).int.bits;
    pub const base = std.math.maxInt(Digit) + 1;

    digits: std.ArrayList(Digit),
    arena: std.heap.ArenaAllocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .digits = .empty,
            .arena = .init(allocator),
        };
    }

    pub fn ensureTotalCapacity(self: *Self, new_capacity: usize) !void {
        try self.digits.ensureTotalCapacity(self.arena.allocator(), new_capacity);
    }

    pub fn deinit(self: *const Self) void {
        self.arena.deinit();
    }

    pub fn addSd(self: *Self, other: Digit) !void {
        return umath.addSd(self, other);
    }

    pub fn add(self: *Self, other: *const Self) !void {
        return umath.add(self, other);
    }

    pub fn subAssumeOrd(self: *Self, other: *const Self) !void {
        return umath.subAssumeOrd(self, other);
    }

    pub fn mul(self: *const Self, other: *const Self) !Self {
        return umath.mul(self, other);
    }

    pub fn addMul(self: *Self, a: *const Self, b: *const Self) !void {
        return self.addMulNaive(a, b);
    }

    pub fn addMulNaive(self: *Self, a: *const Self, b: *const Self) !void {
        return umath.addMulNaive(self, a, b);
    }

    pub fn mulSd(self: *Self, other: Digit) !void {
        return umath.mulSd(self, other);
    }

    pub fn mulAddSd(self: *Self, other: Digit, add_by: Digit) !void {
        return umath.mulAddSd(self, other, add_by);
    }

    pub fn powSd(self: Self, other: Digit) !Self {
        return umath.powSd(self, other);
    }
};

test "ubig add" {
    const allocator = std.testing.allocator;

    const max = ubig.base - 1;

    // 3 + 5 = 8
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{3});
        try b.digits.appendSlice(a.arena.allocator(), &.{5});

        try a.add(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{8}, a.digits.items);
    }

    // max + 1 = 10_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{max});
        try b.digits.appendSlice(a.arena.allocator(), &.{1});

        try a.add(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 0, 1 }, a.digits.items);
    }

    // 1 + max = 10_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{1});
        try b.digits.appendSlice(a.arena.allocator(), &.{max});

        try a.add(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 0, 1 }, a.digits.items);
    }

    // 10_base + max * 10_base = 100_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{ 0, 1 });
        try b.digits.appendSlice(a.arena.allocator(), &.{ 0, max });

        try a.add(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 0, 0, 1 }, a.digits.items);
    }

    // 13_base + (max * 10_base + 5) = 108_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{ 3, 1 });
        try b.digits.appendSlice(a.arena.allocator(), &.{ 5, max });

        try a.add(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 8, 0, 1 }, a.digits.items);
    }

    // 33_base + (max * 10_base + 5) = 128_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{ 3, 3 });
        try b.digits.appendSlice(a.arena.allocator(), &.{ 5, max });

        try a.add(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 8, 2, 1 }, a.digits.items);
    }
}

test "ubig sub" {
    const allocator = std.testing.allocator;

    const max = ubig.base - 1;

    // 5 - 3 = 2
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{5});
        try b.digits.appendSlice(a.arena.allocator(), &.{3});

        try a.subAssumeOrd(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{2}, a.digits.items);
    }

    // 10_base - 3 = (max - 2)
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{ 0, 1 });
        try b.digits.appendSlice(a.arena.allocator(), &.{3});

        try a.subAssumeOrd(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{max - 2}, a.digits.items);
    }
}

test "ubig mul add sd" {
    const allocator = std.testing.allocator;

    const max = ubig.base - 1;

    // 5 * 3 = 15
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{5});

        try a.mulSd(3);

        try std.testing.expectEqualSlices(ubig.Digit, &.{15}, a.digits.items);
    }

    // max * 3 = 20_base + (max - 2)
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{max});

        try a.mulSd(3);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ max - 2, 2 }, a.digits.items);
    }

    // 3 * max = 20_base + (max - 2)
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{3});

        try a.mulSd(max);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ max - 2, 2 }, a.digits.items);
    }

    // 5 * 3 + 2 = 17
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{5});

        try a.mulAddSd(3, 2);

        try std.testing.expectEqualSlices(ubig.Digit, &.{17}, a.digits.items);
    }

    // max * 3 + 3 = 30_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{max});

        try a.mulAddSd(3, 3);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 0, 3 }, a.digits.items);
    }

    // 3 * max + 3 = 30_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{3});

        try a.mulAddSd(max, 3);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 0, 3 }, a.digits.items);
    }

    // max * max + max = max * base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{max});

        try a.mulAddSd(max, max);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 0, max }, a.digits.items);
    }
}

test "ubig mul add" {
    const allocator = std.testing.allocator;

    const max = ubig.base - 1;

    // 3 * 5 = 15
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{3});
        try b.digits.appendSlice(a.arena.allocator(), &.{5});

        const mul = try a.mul(&b);
        defer mul.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{15}, mul.digits.items);
    }

    // 3 * max = 20_base + (max - 2)
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{3});
        try b.digits.appendSlice(a.arena.allocator(), &.{max});

        const mul = try a.mul(&b);
        defer mul.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{ max - 2, 2 }, mul.digits.items);
    }

    // max * 3 = 20_base + (max - 2)
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{max});
        try b.digits.appendSlice(a.arena.allocator(), &.{3});

        const mul = try a.mul(&b);
        defer mul.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{ max - 2, 2 }, mul.digits.items);
    }

    // max * max + max = max * base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        var c: ubig = .init(allocator);
        defer c.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{max});
        try b.digits.appendSlice(a.arena.allocator(), &.{max});
        try c.digits.appendSlice(a.arena.allocator(), &.{max});

        try c.addMul(&a, &b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 0, max }, c.digits.items);
    }

    // max(base) * max(base) + max(base^2) = max(base^3)
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        var c: ubig = .init(allocator);
        defer c.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{ 0, max });
        try b.digits.appendSlice(a.arena.allocator(), &.{ 0, max });
        try c.digits.appendSlice(a.arena.allocator(), &.{ 0, 0, max });

        try c.addMul(&a, &b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 0, 0, 0, max }, c.digits.items);
    }
}

test "ubig pow sd" {
    const allocator = std.testing.allocator;

    // const max = ubig.base - 1;

    // 3^5 = 243
    {
        var a: ubig = .init(allocator);
        try a.digits.appendSlice(a.arena.allocator(), &.{3});

        const pow = try a.powSd(5);
        defer pow.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{243}, pow.digits.items);
    }

    // (10_base)^5 = 100000_base
    {
        var a: ubig = .init(allocator);
        try a.digits.appendSlice(a.arena.allocator(), &.{ 0, 1 });

        const pow = try a.powSd(5);
        defer pow.deinit();

        try std.testing.expectEqualSlices(ubig.Digit, &.{ 0, 0, 0, 0, 0, 1 }, pow.digits.items);
    }
}
