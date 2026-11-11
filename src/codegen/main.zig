const std = @import("std");
const parser = @import("parser.zig");
const Io = std.Io;

const raw = @embedFile("__protocol__.json");

pub fn main(init: std.process.Init) !void {
    var p: parser.Parser = undefined;
    var scanner: std.json.Scanner = .initCompleteInput(init.gpa, raw);
    defer scanner.deinit();

    try p.parse(&scanner);
}

const CodeGenWriter = struct {
    writer: *std.Io.Writer,

    fn lf(self: @This()) void {
        self.writer.writeByte('\n') catch unreachable;
    }

    fn literal(self: @This(), data: []const u8) void {
        _ = self.writer.write(data) catch unreachable;
    }

    fn formatted(self: @This(), comptime fmt: []const u8, args: anytype) void {
        self.writer.print(fmt, args) catch unreachable;
    }

    fn flush(self: @This()) void {
        self.writer.flush() catch unreachable;
    }
};

const TypeDefinition = struct {
    fields: []FieldDefinition,
};

const FieldDefinition = struct {};

const St = struct {
    foo: u32,
    bar: bool,
};

const ct_allocator: std.mem.Allocator = .{
    .ptr = undefined,
    .vtable = &ct_allocator_impl.vtable,
};

const ct_allocator_impl = struct {
    const vtable: std.mem.Allocator.VTable = .{
        .alloc = &alloc,
        .resize = &std.mem.Allocator.noResize,
        .remap = &std.mem.Allocator.noRemap,
        .free = &std.mem.Allocator.noFree,
    };

    fn alloc(
        _: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        _: usize,
    ) ?[*]u8 {
        if (!@inComptime()) std.debug.panic("Should not be called at runtime.", .{});
        comptime {
            var buffer: [len]u8 align(alignment.toByteUnits()) = undefined;
            return &buffer;
        }
    }
};
