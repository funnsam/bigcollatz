const ubig = @import("ubig.zig").ubig;

const Digit = ubig.Digit;
const DoubleDigit = ubig.DoubleDigit;

const bits = ubig.bits;
const base = ubig.base;

pub fn add(a: *ubig, b: *const ubig) !void {
    var carry: Digit = 0;

    const result_size = @max(a.digits.items.len, b.digits.items.len) + 1;
    try a.ensureTotalCapacity(result_size);

    const a_len = a.digits.items.len;
    a.digits.items.len = result_size;

    for (0..result_size - 1) |i| {
        const ad = if (i < a_len) a.digits.items[i] else 0;
        const bd = if (i < b.digits.items.len) b.digits.items[i] else 0;

        const r = addCarry(ad, bd, carry);
        carry = r.c;

        a.digits.items[i] = r.r;
    }

    if (carry != 0) {
        a.digits.items[result_size - 1] = carry;
    } else {
        a.digits.items.len -= 1;
    }
}

pub fn subAssumeOrd(a: *ubig, b: *const ubig) !void {
    var borrow: Digit = 0;

    var final_len: usize = 0;
    for (0..a.digits.items.len) |i| {
        const ad = a.digits.items[i];
        const bd = if (i < b.digits.items.len) b.digits.items[i] else 0;

        const r = subBorrow(ad, bd, borrow);
        a.digits.items[i] = r.r;
        borrow = r.c;

        if (r.r != 0) final_len = i + 1;
    }

    a.digits.items.len = final_len;
}

pub fn mul(a: *const ubig, b: *const ubig) !ubig {
    var ret: ubig = .init(a.arena.child_allocator);
    errdefer ret.deinit();

    try addMul(&ret, a, b);
    return ret;
}

pub fn addMul(c: *ubig, a: *const ubig, b: *const ubig) !void {
    return addMulNaive(c, a, b);
}

pub fn addMulNaive(c: *ubig, a: *const ubig, b: *const ubig) !void {
    if (a.digits.items.len > 0 and b.digits.items.len == 0) {
        return;
    }

    const result_size = @max(c.digits.items.len, a.digits.items.len + b.digits.items.len);
    const orig_size = c.digits.items.len;

    try c.ensureTotalCapacity(result_size);
    c.digits.items.len = result_size;
    @memset(c.digits.items[orig_size..], 0);

    for (0..b.digits.items.len) |j| {
        var carry: Digit = 0;

        for (0..a.digits.items.len) |i| {
            const ad = a.digits.items[i];
            const bd = b.digits.items[j];

            const r = mulAdd2Carry(ad, bd, c.digits.items[i + j], carry);
            carry = r.c;

            c.digits.items[i + j] = r.r;
        }

        c.digits.items[a.digits.items.len + j] += carry;
    }

    if (c.digits.getLast() == 0) {
        c.digits.items.len -= 1;
    }
}

pub fn mulSd(a: *ubig, b: Digit) !void {
    try mulAddSd(a, b, 0);
}

pub fn mulAddSd(a: *ubig, b: Digit, add_by: Digit) !void {
    var carry: Digit = add_by;

    const result_size = a.digits.items.len + 1;
    try a.ensureTotalCapacity(result_size);

    const a_len = a.digits.items.len;

    for (0..a_len) |i| {
        const ad = a.digits.items[i];

        const r = mulAddCarry(ad, b, carry);
        carry = r.c;

        a.digits.items[i] = r.r;
    }

    if (carry != 0) {
        a.digits.items.len += 1;
        a.digits.items[a_len] = carry;
    }
}

pub fn powSd(_a: ubig, _b: Digit) !ubig {
    var a: ubig = _a;
    defer a.deinit();

    var b: Digit = _b;

    var result: ubig = .init(a.arena.child_allocator);
    errdefer result.deinit();

    try result.digits.append(result.arena.allocator(), 1);

    while (b > 0) {
        if (b % 2 != 0) {
            const new_result = try mul(&result, &a);
            result.deinit();
            result = new_result;
        }

        b /= 2;
        const new_a = try mul(&a, &a);
        a.deinit();
        a = new_a;
    }

    return result;
}

// carrying op utils
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

fn mulAddCarry(a: Digit, b: Digit, c: Digit) CarryOp {
    const d = @as(DoubleDigit, @intCast(a)) * @as(DoubleDigit, @intCast(b));
    const e = @addWithOverflow(@as(Digit, @truncate(d)), c);

    return .{
        .r = e.@"0",
        .c = @as(Digit, @truncate(d >> bits)) + @as(Digit, @intCast(e.@"1")),
    };
}

fn mulAdd2Carry(a: Digit, b: Digit, c: Digit, d: Digit) CarryOp {
    const e = mulAddCarry(a, b, c);
    const f = @addWithOverflow(e.r, d);

    return .{
        .r = f.@"0",
        .c = e.c + f.@"1",
    };
}
