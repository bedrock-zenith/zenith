const std = @import("std");
const Io = std.Io;

const zenith = @import("zenith");
const webrtc = @import("web-rtc");

pub fn listen(io: Io, ip: std.Io.net.IpAddress) !void {
    var server = try Io.net.IpAddress.listen(&ip, io, .{});
    var read_buffer: [65536]u8 = undefined;
    var write_buffer: [65536]u8 = undefined;

    while (true) {
        var stream = try server.accept(io);
        defer stream.close(io);

        var reader = stream.reader(io, &read_buffer);
        var writer = stream.writer(io, &write_buffer);

        const reader_interface = &reader.interface;
        const writer_interface = &writer.interface;

        try reader_interface.fillMore();
        const body = reader_interface.buffered();
        if (body[0] == 22) continue;

        var web_server: std.http.Server = .init(reader_interface, writer_interface);
        handle(&web_server) catch continue;

        std.log.info("Connection Closed", .{});
    }
}

pub const Motd = struct {
    name: []const u8,
    protocol: u32,
    version: []const u8,
    level: []const u8,
    players: u32,
    maxPlayers: u32,
    gameType: u32,
};

pub fn handle(web_server: *std.http.Server) !void {
    var request = try web_server.receiveHead();
    std.log.info("url: {s}, method: {}", .{ request.head.target, request.head.method });

    if (std.mem.startsWith(u8, request.head.target, "/v1/join/")) {
        var iter = request.iterateHeaders();
        var length: u64 = 0;
        while (iter.next()) |header| {
            if (std.mem.eql(u8, "Content-Length", header.name)) {
                length = try std.fmt.parseInt(u64, header.value, 10);
            }
        }

        if (request.head.method == .POST) {
            const body_reader = web_server.reader.bodyReader(&.{}, .none, length);
            const buffer = try body_reader.readAllocAll(std.heap.smp_allocator, @as(usize, length));
            defer std.heap.smp_allocator.free(buffer);

            //std.log.warn("SDP: {s}", .{buffer});
            var tokenizer: webrtc.sdp.SdpTokenizer = .{ .buffer = buffer };
            std.log.info("size: {d}", .{buffer.len});
            while (true) {
                const character = tokenizer.next() catch |err| switch (err) {
                    error.EndOfBuffer => break,
                    else => return err,
                };

                const value = tokenizer.next() catch |err| switch (err) {
                    error.EndOfBuffer => break,
                    else => return err,
                };

                std.log.info("char: {c}, data: {s}", .{ character.identity, value.value_chunk_end });
            }
        }

        try request.respond("", .{
            .status = .bad_request,
        });

        return;
    }

    if (std.mem.startsWith(u8, request.head.target, "/v1/join") and request.head.method == .GET) {
        std.log.info("identified", .{});
        var some_data_buffer: [1024]u8 = undefined;
        var data = std.Io.Writer.fixed(&some_data_buffer);
        try std.json.Stringify.value(
            Motd{
                .name = "Test Server",
                .protocol = 2225,
                .version = "1.26.50",
                .level = "Provider name",
                .gameType = 0,
                .maxPlayers = 40,
                .players = 5,
            },
            .{},
            &data,
        );

        std.log.info("json motd: {s}", .{data.buffered()});

        try request.respond(data.buffered(), .{
            .status = .ok,
            .extra_headers = &.{.{ .name = "Content-Type", .value = "application/json" }},
        });

        return;
    }

    try request.respond("", .{
        .status = .bad_request,
    });
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var task = io.async(listen, .{ io, std.Io.net.IpAddress{ .ip4 = try .parse("0.0.0.0", 19132) } });
    //errdefer task.cancel(io) catch {};

    try task.await(io);
}
