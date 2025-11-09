const std = @import("std");
const bigcollatz = @import("bigcollatz");

const counters = @import("counters.zig");
const solver = @import("solver.zig");

var in_buf: [4096]u8 = undefined;
var out_buf: [4096]u8 = undefined;

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var stdin = std.fs.File.stdin().reader(&in_buf);
    var stdout = std.fs.File.stdout().writer(&out_buf);

    try stdout.interface.writeAll("Number: ");
    try stdout.interface.flush();

    const in = (try stdin.interface.takeDelimiter('\n')) orelse @panic("no input");

    var timer: std.time.Timer = try .start();
    const num = try bigcollatz.rpn(allocator, in);

    try stdout.interface.print("Parsing done in {D}\n", .{timer.read()});
    try stdout.interface.flush();

    timer.reset();

    try solver.solve(num);

    const total_iter = counters.even + counters.odd + 1;
    const even_percentage = @as(f64, @floatFromInt(counters.even)) / @as(f64, @floatFromInt(total_iter)) * 100.0;

    try stdout.interface.print("Time taken: {D}\n", .{timer.read()});
    try stdout.interface.print("Even count: {d}\n", .{counters.even});
    try stdout.interface.print("Odd count:  {d}\n", .{counters.odd});
    try stdout.interface.print("Even ratio: {d:.02}%\n", .{even_percentage});
    try stdout.interface.print("Iterations: {d}\n", .{total_iter});
    try stdout.interface.flush();
}
