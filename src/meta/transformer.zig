const std = @import("std");
const Scanner = std.json.Scanner;
const eql = std.mem.eql;
const Writer = std.Io.Writer;

pub fn translate(in: *Scanner, out: *Writer) !void {
    const obj: JsonObject = .{ .scanner = in };
    try obj.start();
    while (try obj.next()) |key| {
        try out.print("KEY('{s}'): \n", .{key});

        if (eql(u8, key, "name") or
            eql(u8, key, "is_bind_type") or
            eql(u8, key, "bind_type"))
        {
            try in.skipValue();
        } else if (eql(u8, key, "enums")) {
            const array: ArrayObject = .{ .scanner = in };
            try array.start();
            while (try array.next()) |_| {
                const en: JsonObject = .{ .scanner = in };
                try en.start();
                try translateEnum(en, out);
            }
        } else try in.skipValue();
    }
    try out.print("Finished", .{});
}

pub fn translateEnum(obj: JsonObject, out: *Writer) !void {
    var enum_data: EnumInformation = .{ .name = "", .hash = "", .backing_integer = "" };
    while (try obj.next()) |key| {
        if (std.mem.eql(u8, key, "name")) {
            enum_data.name = (try obj.scanner.next()).string;
        } else if (std.mem.eql(u8, key, "hash")) {
            enum_data.hash = (try obj.scanner.next()).string;
        } else if (std.mem.eql(u8, key, "enum_kind")) {
            enum_data.hash = (try obj.scanner.next()).string;
        }
        try out.print("OBJECT_KEY('{s}'): \n", .{key});
        try obj.scanner.skipValue();
    }
}

const EnumInformation = struct {
    name: []const u8,
    hash: []const u8,
    backing_integer: []const u8,
};

const JsonObject = struct {
    scanner: *Scanner,
    pub fn start(object: JsonObject) !void {
        const token = try object.scanner.next();
        std.debug.assert(token == .object_begin);
    }
    pub fn next(object: JsonObject) !?[]const u8 {
        const token = try object.scanner.next();
        if (token == .object_end) return null;
        if (token == .string) return token.string;
        std.log.debug("Test: {}", .{token});
        return error.SyntaxError;
    }
};

const ArrayObject = struct {
    scanner: *Scanner,
    pub fn start(object: ArrayObject) !void {
        const token = try object.scanner.next();
        std.debug.assert(token == .array_begin);
    }
    pub fn next(object: ArrayObject) !?void {
        const token = try object.scanner.peekNextTokenType();
        if (token == .array_end) {
            _ = try object.scanner.next();
            return null;
        }
    }
};
