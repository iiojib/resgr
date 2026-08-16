const Flags = @This();

const std = @import("std");
const process = std.process;
const mem = std.mem;

help: bool = false,
version: bool = false,
ignore_sigint: bool = false,
unknown_arg: ?[]const u8 = null,

pub fn fromArgsIterator(args: *process.Args.Iterator) Flags {
    var flags: Flags = .{};

    _ = args.skip();
    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
            flags.help = true;
        } else if (mem.eql(u8, arg, "-v") or mem.eql(u8, arg, "--version")) {
            flags.version = true;
        } else if (mem.eql(u8, arg, "-i")) {
            flags.ignore_sigint = true;
        } else {
            flags.unknown_arg = arg;
            break;
        }
    }

    return flags;
}
