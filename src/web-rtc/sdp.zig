const std = @import("std");

pub const SdpState = enum {
    identity_character,
    identity_sign,
    identity_value,
    sentinel_r,
    sentinel_n,
};

pub const SdpToken = union(enum) {
    identity: u8,
    value_chunk: []const u8,
    value_chunk_end: []const u8,
};

pub const SdpTokenizer = struct {
    buffer: []const u8 = &.{},
    index: usize = 0,
    state: SdpState = .identity_character,
    pub fn feed(self: *@This(), buffer: []const u8) void {
        self.buffer = buffer;
        self.index = 0;
    }
    pub fn next(self: *@This()) error{ UnexpectedToken, EndOfBuffer }!SdpToken {
        while (true) switch (self.state) {
            .identity_character => {
                const char = try nextChar(self);
                self.state = .identity_sign;
                return .{ .identity = char };
            },
            .identity_sign => {
                if (try nextChar(self) != '=') return error.UnexpectedToken;
                self.state = .identity_value;
            },
            .identity_value => {
                const start = self.index;
                while (true) {
                    if (self.index >= self.buffer.len) break;
                    switch (self.buffer[self.index]) {
                        '\r' => {
                            self.state = .sentinel_r;
                            break;
                        },
                        // Specs say it should always be CRLF, but its good practice to handle only LF new lines
                        '\n' => {
                            self.state = .sentinel_n;
                            break;
                        },
                        else => self.index += 1,
                    }
                }

                if (self.index - start <= 0) return error.EndOfBuffer;

                // In this case we didn't hit the end of the stream yet and the value wasn't terminated by end line
                if (self.state == .identity_value) return .{ .value_chunk = self.buffer[start..self.index] };

                return .{ .value_chunk_end = self.buffer[start..self.index] };
            },
            .sentinel_r => {
                if (try nextChar(self) != '\r') return error.UnexpectedToken;
                self.state = .sentinel_n;
            },
            .sentinel_n => {
                if (try nextChar(self) != '\n') return error.UnexpectedToken;
                self.state = .identity_character;
            },
        };
    }
    inline fn nextChar(self: *@This()) error{EndOfBuffer}!u8 {
        if (self.index >= self.buffer.len) return error.EndOfBuffer;
        defer self.index += 1;

        return self.buffer[self.index];
    }
};
