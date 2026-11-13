const std = @import("std");
const Scanner = std.json.Scanner;
const eql = std.mem.eql;
const Writer = std.Io.Writer;

pub const Integer = struct {
    bit_size: u16,
    signness: std.lang.Signedness,

    pub const default: Integer = .{ .bit_size = 32, .signness = .unsigned };

    pub const Metadata = struct {
        reinterpret: Integer,
        encoding: Integer.Encoding,
    };

    pub const Encoding = enum {
        little,
        big,
        leb128,
        zleb128,
    };

    pub const Field = struct {
        int: Integer,
        meta: Metadata,
    };
};
pub const Float = struct {
    bit_size: u8,

    pub const Metadata = struct {
        encoding: Float.Encoding,
    };

    pub const Encoding = enum {
        little,
        big,
    };

    pub const Field = struct {
        int: Float,
        meta: Metadata,
    };
};
pub const String = struct {
    pub const Metadata = struct {
        length: Integer,
    };

    pub const Field = struct {
        length: Integer.Field,
    };
};
pub const Array = struct {
    child: *const DataType,
};

pub const Enum = struct {
    identifier: Identifier,
    backing: Integer,
    first: ?*const EnumIdentifier = null,
    last: ?*const EnumIdentifier = null,

    const BIND_TYPE = "enum";

    pub fn append(e: *Enum, ei: *const EnumIdentifier) void {
        if (e.last) |last| {
            last.next = ei;
            e.last = ei;
        } else {
            e.first = ei;
            e.last = ei;
        }
    }

    pub const EnumIdentifier = struct {
        name: []const u8,
        value: ?u64 = null,
        next: ?*const EnumIdentifier = null,
    };

    pub const Metadata = Integer.Metadata;
};

pub const DataType = union(enum) {
    int: Integer,
    float: Float,
    string: String,
    array: Array,
    @"enum": Enum,
};

const Identifier = []const u8;

pub const EnumDefinition = struct {
    name: Identifier,
    hash: []const u8,
    enum_literals: []const u8,
    enum_values: ?[]const u64 = null,
    backing_integer: ?u8,
};

pub const Parser = struct {
    arena: std.mem.Allocator,
    enums: std.ArrayList(Enum),

    pub fn parse(parser: *Parser, scanner: *Scanner) !void {
        const obj: JsonObject = try .start(scanner);
        main: while (try obj.next()) |key| {
            inline for (@typeInfo(ParserDispatch).@"struct".decl_names) |name| {
                if (std.mem.eql(u8, key, name)) {
                    const array: JsonArray = try .start(scanner);
                    while (try array.next()) |_| {
                        const TYPE = @field(ParserDispatch, name);
                        _ = try TYPE.parse(parser, scanner);
                    }
                    continue :main;
                }
            }
            try scanner.skipValue();
        }
    }

    pub const ParserDispatch = struct {
        pub const enums = struct {
            pub fn parse(_: *Parser, scanner: *Scanner) !Enum {
                var enum_info: Enum = .{ .identifier = &.{}, .backing = .default };
                const obj: JsonObject = try .start(scanner);
                while (try obj.next()) |key| {
                    if (std.mem.eql(u8, key, "name")) {
                        const token = try scanner.next();
                        enum_info.identifier = token.string;

                        std.log.info("name: {s}", .{enum_info.identifier});
                    } else try scanner.skipValue();
                }

                return enum_info;
            }
        };
    };
};

const JsonObject = struct {
    scanner: *Scanner,
    pub fn start(scanner: *Scanner) !JsonObject {
        const token = try scanner.next();
        std.debug.assert(token == .object_begin);
        return .{ .scanner = scanner };
    }
    pub fn next(object: JsonObject) !?[]const u8 {
        const token = try object.scanner.next();
        if (token == .object_end) return null;
        if (token == .string) return token.string;
        std.log.debug("Test: {}", .{token});
        return error.SyntaxError;
    }
};

const JsonArray = struct {
    scanner: *Scanner,
    pub fn start(scanner: *Scanner) !JsonArray {
        const token = try scanner.next();
        std.debug.assert(token == .array_begin);
        return .{ .scanner = scanner };
    }
    pub fn next(object: JsonArray) !?void {
        const token = try object.scanner.peekNextTokenType();
        if (token == .array_end) {
            _ = try object.scanner.next();
            return null;
        }
    }
};
