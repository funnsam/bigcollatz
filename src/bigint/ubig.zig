const std = @import("std");

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

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    pub fn add(self: *Self, other: *const Self) !void {
        var carry: Digit = 0;

        const result_size = @max(self.digits.items.len, other.digits.items.len) + 1;
        try self.ensureTotalCapacity(result_size);

        const self_len = self.digits.items.len;
        self.digits.items.len = result_size;

        for (0..result_size - 1) |i| {
            const a = if (i < self_len) self.digits.items[i] else 0;
            const b = if (i < other.digits.items.len) other.digits.items[i] else 0;

            const r = addCarry(a, b, carry);
            carry = r.c;

            self.digits.items[i] = r.r;
        }

        if (carry != 0) {
            self.digits.items[result_size - 1] = carry;
        } else {
            self.digits.items.len -= 1;
        }
    }

    pub fn subAssumeOrd(self: *Self, other: *const Self) !void {
        var borrow: Digit = 0;

        var final_len: usize = 0;
        for (0..self.digits.items.len) |i| {
            const a = self.digits.items[i];
            const b = if (i < other.digits.items.len) other.digits.items[i] else 0;

            const r = subBorrow(a, b, borrow);
            self.digits.items[i] = r.r;
            borrow = r.c;

            if (r.r != 0) final_len = i + 1;
        }

        self.digits.items.len = final_len;
    }

    pub fn mulSd(self: *Self, other: Digit) !void {
        var carry: Digit = 0;

        const result_size = self.digits.items.len + 1;
        try self.ensureTotalCapacity(result_size);

        const self_len = self.digits.items.len;

        for (0..self_len) |i| {
            const a = self.digits.items[i];

            const r = mulCarry(a, other, carry);
            carry = r.c;

            self.digits.items[i] = r.r;
        }

        if (carry != 0) {
            self.digits.items.len += 1;
            self.digits.items[self_len] = carry;
        }
    }

    const CarryOp = struct {
        r: Digit,
        c: Digit,
    };

    fn addCarry(a: Digit, b: Digit, c: Digit) CarryOp {
        const d = @addWithOverflow(a, b);
        const e = @addWithOverflow(d.@"0", c);

        return .{
            .r = e.@"0",
            .c = @intCast(d.@"1" | e.@"1"),
        };
    }

    fn subBorrow(a: Digit, b: Digit, c: Digit) CarryOp {
        const d = @subWithOverflow(a, b);
        const e = @subWithOverflow(d.@"0", c);

        return .{
            .r = e.@"0",
            .c = @intCast(d.@"1" | e.@"1"),
        };
    }

    fn mulCarry(a: Digit, b: Digit, c: Digit) CarryOp {
        const d = @as(DoubleDigit, @intCast(a)) * @as(DoubleDigit, @intCast(b));
        const e = @addWithOverflow(@as(Digit, @truncate(d)), c);

        return .{
            .r = e.@"0",
            .c = @as(Digit, @truncate(d >> bits)) + @as(Digit, @intCast(e.@"1")),
        };
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

        try std.testing.expectEqualSlices(ubig.Digit, &.{0, 1}, a.digits.items);
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

        try std.testing.expectEqualSlices(ubig.Digit, &.{0, 1}, a.digits.items);
    }

    // 10_base + max * 10_base = 100_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{0, 1});
        try b.digits.appendSlice(a.arena.allocator(), &.{0, max});

        try a.add(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{0, 0, 1}, a.digits.items);
    }

    // 13_base + (max * 10_base + 5) = 108_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{3, 1});
        try b.digits.appendSlice(a.arena.allocator(), &.{5, max});

        try a.add(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{8, 0, 1}, a.digits.items);
    }

    // 33_base + (max * 10_base + 5) = 128_base
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        var b: ubig = .init(allocator);
        defer b.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{3, 3});
        try b.digits.appendSlice(a.arena.allocator(), &.{5, max});

        try a.add(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{8, 2, 1}, a.digits.items);
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

        try a.digits.appendSlice(a.arena.allocator(), &.{0, 1});
        try b.digits.appendSlice(a.arena.allocator(), &.{3});

        try a.subAssumeOrd(&b);

        try std.testing.expectEqualSlices(ubig.Digit, &.{max - 2}, a.digits.items);
    }
}

test "ubig mul sd" {
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

    // max * 3 = 2 + (max - 2)
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{max});

        try a.mulSd(3);

        try std.testing.expectEqualSlices(ubig.Digit, &.{max - 2, 2}, a.digits.items);
    }

    // 3 * max = 2 + (max - 2)
    {
        var a: ubig = .init(allocator);
        defer a.deinit();

        try a.digits.appendSlice(a.arena.allocator(), &.{3});

        try a.mulSd(max);

        try std.testing.expectEqualSlices(ubig.Digit, &.{max - 2, 2}, a.digits.items);
    }
}
