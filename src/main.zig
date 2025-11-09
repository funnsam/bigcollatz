const std = @import("std");
const bigcollatz = @import("bigcollatz");

var in_buf: [4096]u8 = undefined;
var out_buf: [4096]u8 = undefined;

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var stdin = std.fs.File.stdin().reader(&in_buf);
    var stdout = std.fs.File.stdout().writer(&out_buf);

    try stdout.interface.writeAll("Number: ");
    try stdout.interface.flush();

    const in = (try stdin.interface.takeDelimiter('\n')) orelse @panic("no input");
    var num = try bigcollatz.rpn(allocator, in);

    try stdout.interface.writeAll("Parse done\n");
    try stdout.interface.flush();

    var even_counter: u64 = 0;
    var odd_counter: u64 = 0;

    while (!std.mem.eql(bigcollatz.ubig.Digit, num.digits.items, &.{1})) {
        if (num.isEven()) {
            const rep = num.ctz();
            even_counter += rep;

            num.rsh(rep);
        } else {
            odd_counter += 1;
            try num.mulAddSd(3, 1);
        }
    }

    const total_iter = even_counter + odd_counter + 1;
    const even_percentage = @as(f64, @floatFromInt(even_counter)) / @as(f64, @floatFromInt(total_iter)) * 100.0;

    try stdout.interface.print("Even count: {d}\n", .{even_counter});
    try stdout.interface.print("Odd count:  {d}\n", .{odd_counter});
    try stdout.interface.print("Even ratio: {d:.02}%\n", .{even_percentage});
    try stdout.interface.print("Iterations: {d}\n", .{total_iter});
    try stdout.interface.flush();
}
