const std = @import("std");
const posix = std.posix;
const process = std.process;
const mem = std.mem;
const Io = std.Io;

const build_options = @import("build_options");

const Flags = @import("Flags.zig");
const Propagator = @import("Propagator.zig");

const help =
    \\Usage: resgr [options]
    \\
    \\Options:
    \\  -h, --help      Show this help message and exit.
    \\  -v, --version   Show the version and exit.
    \\  -i              Ignore the SIGINT signal.
    \\
;

const buffer_size = 4096;

fn sigIntNoop(_: posix.SIG) callconv(.c) void {}

pub fn main(init: process.Init) !void {
    const arena: mem.Allocator = init.arena.allocator();
    const io = init.io;

    var args = try init.minimal.args.iterateAllocator(arena);
    const flags: Flags = .fromArgsIterator(&args);

    if (flags.unknown_arg) |arg| {
        process.fatal("Unknown argument: {s}\n\n{s}", .{ arg, help });
    }

    if (flags.version) {
        try Io.File.stdout().writeStreamingAll(io, "Version " ++ build_options.version ++ "\n");
        return;
    }

    if (flags.help) {
        try Io.File.stdout().writeStreamingAll(io, help);
        return;
    }

    if (flags.ignore_sigint) {
        const action: posix.Sigaction = .{
            .handler = .{ .handler = sigIntNoop },
            .mask = posix.sigemptyset(),
            .flags = 0,
        };

        posix.sigaction(posix.SIG.INT, &action, null);
    }

    var stdin_buffer: [buffer_size]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .initStreaming(.stdin(), io, &stdin_buffer);
    const stdin_reader = &stdin_file_reader.interface;

    var stdout_buffer: [buffer_size]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .initStreaming(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var propagator: Propagator = .{};

    try propagator.process(stdin_reader, stdout_writer);

    try stdout_writer.writeAll("\x1b[m");
    try stdout_writer.flush();
}

test {
    std.testing.refAllDecls(@This());
}
