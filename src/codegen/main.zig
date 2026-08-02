const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    var buffer: [4096]u8 = undefined;
    var file_writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);

    var codegen: CodeGenWriter = .{
        .writer = &file_writer.interface,
    };
    defer codegen.flush();

    codegen.lf();
    codegen.formatted("fn read({s}) void {{\n\n}}", .{"param: u8"});
    codegen.lf();
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
