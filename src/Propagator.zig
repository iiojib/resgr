const Propagator = @This();

const std = @import("std");
const Io = std.Io;

const Sgr = @import("Sgr.zig");

sgr: Sgr = .{},
state: ParseState = .plain,

pub fn process(self: *Propagator, reader: *Io.Reader, writer: *Io.Writer) !void {
    while (true) {
        reader.fillMore() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        var offset: usize = 0;
        const buffered = reader.buffered();

        for (buffered, 0..) |byte, i| {
            self.parseByte(byte);

            if (byte == '\n') {
                try writer.writeAll(buffered[offset..i]);
                try writer.writeAll("\x1b[m");
                try writer.writeAll("\n");
                try writer.flush();
                try self.writeSgr(writer);

                offset = i + 1;
            }
        }

        try writer.writeAll(buffered[offset..]);
        try writer.flush();

        reader.tossBuffered();

        offset = 0;
    }
}

fn parseByte(self: *Propagator, byte: u8) void {
    switch (self.state) {
        .plain => if (byte == 0x1b) {
            self.state = .escape;
        },

        .escape => if (byte == '[') {
            self.state = .{ .csi = .{} };
        } else if (byte != 0x1b) {
            self.state = .plain;
        },

        .csi => |*csi| {
            const status = csi.parseByte(byte);

            if (status == .complete) self.sgr.apply(&csi.sgr);
            if (status != .incomplete) self.state = .plain;
        },
    }
}

fn writeSgr(self: *const Propagator, writer: *Io.Writer) !void {
    const sgr = &self.sgr;

    try writer.writeAll("\x1b[");

    if (sgr.intensity) |intensity| try writer.print(";{d}", .{intensity.toCode()});
    if (sgr.italic) |italic| try writer.print(";{d}", .{italic.toCode()});
    if (sgr.underline) |underline| try writer.print(";{d}", .{underline.toCode()});
    if (sgr.blink) |blink| try writer.print(";{d}", .{blink.toCode()});
    if (sgr.inverse orelse false) try writer.writeAll(";7");
    if (sgr.concealed orelse false) try writer.writeAll(";8");
    if (sgr.crossed_out orelse false) try writer.writeAll(";9");
    if (sgr.font) |font| try writer.print(";{d}", .{font.toCode()});
    if (sgr.foreground) |color| try Sequence(5).fromColor(.foreground, color).write(writer);
    if (sgr.background) |color| try Sequence(5).fromColor(.background, color).write(writer);
    if (sgr.underline_color) |color| try Sequence(5).fromColor(.underline, color).write(writer);
    if (sgr.framing) |framing| try writer.print(";{d}", .{framing.toCode()});
    if (sgr.overline orelse false) try writer.writeAll(";53");
    if (sgr.script) |script| try writer.print(";{d}", .{script.toCode()});
    if (sgr.ideogram) |ideogram| try writer.print(";{d}", .{ideogram.toCode()});

    try writer.writeAll("m");
}

fn Sequence(comptime size: usize) type {
    return struct {
        bytes: [size]u8 = .{0} ** size,
        len: usize = 0,

        pub fn fromCode(code: u8) Sequence(size) {
            return .{
                .bytes = .{code} ++ .{0} ** (size - 1),
                .len = 1,
            };
        }

        pub fn fromBytes(comptime len: usize, bytes: [len]u8) Sequence(size) {
            return .{
                .bytes = bytes ++ .{0} ** (size - len),
                .len = len,
            };
        }

        pub fn fromColor(target: Sgr.ColorTarget, color: Sgr.Color) Sequence(size) {
            return switch (color) {
                .default => switch (target) {
                    .foreground => .fromCode(39),
                    .background => .fromCode(49),
                    .underline => .fromCode(59),
                },

                .ansi => .fromCode(color.ansi.toCode(target)),
                .indexed => .fromBytes(3, .{ target.toCode(), 5, color.indexed }),
                .rgb => .fromBytes(5, .{ target.toCode(), 2, color.rgb[0], color.rgb[1], color.rgb[2] }),
            };
        }

        pub fn append(self: *Sequence(size), byte: u8) void {
            if (self.len >= size) unreachable;

            self.bytes[self.len] = byte;
            self.len += 1;
        }

        pub fn write(self: *const Sequence(size), writer: *Io.Writer) !void {
            for (self.bytes[0..self.len]) |byte| try writer.print(";{d}", .{byte});
        }
    };
}

pub const Code = struct {
    value: u8 = 0,
    overflow: bool = false,

    pub fn parseByte(self: *Code, byte: u8) void {
        var overflow: u1 = undefined;

        self.value, overflow = @mulWithOverflow(self.value, 10);
        if (overflow == 1) self.overflow = true;

        self.value, overflow = @addWithOverflow(self.value, byte - '0');
        if (overflow == 1) self.overflow = true;
    }
};

const Csi = struct {
    code: Code = .{},
    sgr: Sgr = .{},
    sequence: ?Sequence(5) = null,

    pub const Status = enum {
        incomplete,
        complete,
        invalid,
    };

    pub fn parseCode(self: *Csi) void {
        const code = self.code.value;
        const overflow = self.code.overflow;
        const sgr = &self.sgr;

        if (self.sequence) |*seq| {
            var color: ?Sgr.Color = null;

            switch (seq.len) {
                1 => if ((code == 2 or code == 5) and !overflow) {
                    seq.append(code);
                } else {
                    self.sequence = null;
                },

                2 => switch (seq.bytes[1]) {
                    2 => seq.append(code),
                    5 => color = .fromIndex(code),
                    else => unreachable,
                },

                3 => seq.append(code),
                4 => color = .fromBytes(seq.bytes[2..4].* ++ .{code}),
                else => unreachable,
            }

            if (color) |clr| {
                switch (seq.bytes[0]) {
                    38 => sgr.foreground = clr,
                    48 => sgr.background = clr,
                    58 => sgr.underline_color = clr,
                    else => unreachable,
                }

                self.sequence = null;
                return;
            }

            if (self.sequence != null) return;
        }

        if (overflow) return;

        switch (code) {
            0 => sgr.* = .default(),
            1, 2, 22 => sgr.intensity = .fromCode(code),
            3, 20, 23 => sgr.italic = .fromCode(code),
            4, 21, 24 => sgr.underline = .fromCode(code),
            5, 6, 25 => sgr.blink = .fromCode(code),
            7 => sgr.inverse = true,
            8 => sgr.concealed = true,
            9 => sgr.crossed_out = true,
            10...19 => sgr.font = .fromCode(code),
            27 => sgr.inverse = false,
            28 => sgr.concealed = false,
            29 => sgr.crossed_out = false,
            30...37, 90...97 => sgr.foreground = .fromCode(code),
            38 => self.sequence = .fromCode(code),
            39 => sgr.foreground = .default,
            40...47, 100...107 => sgr.background = .fromCode(code),
            48 => self.sequence = .fromCode(code),
            49 => sgr.background = .default,
            51, 52, 54 => sgr.framing = .fromCode(code),
            53 => sgr.overline = true,
            55 => sgr.overline = false,
            58 => self.sequence = .fromCode(code),
            59 => sgr.underline_color = .default,
            60...65 => sgr.ideogram = .fromCode(code),
            73...75 => sgr.script = .fromCode(code),
            else => {},
        }
    }

    pub fn parseByte(self: *Csi, byte: u8) Status {
        switch (byte) {
            '0'...'9' => self.code.parseByte(byte),

            ';', 'm' => {
                self.parseCode();
                self.code = .{};

                if (byte == 'm') return .complete;
            },

            else => return .invalid,
        }

        return .incomplete;
    }
};

const ParseState = union(enum) {
    plain,
    escape,
    csi: Csi,
};

test "empty and unterminated streams" {
    try expectProcess("", 1, "");
    try expectProcess("plain text", 1, "plain text");
    try expectProcess("\n", 3, "\x1b[m\n\x1b[m");
}

test "resets and restores styles at each newline" {
    try expectProcess(
        "\x1b[31mfirst\nsecond\x1b[0m\nthird\n",
        2,
        "\x1b[31mfirst\x1b[m\n\x1b[;31msecond\x1b[0m\x1b[m\n\x1b[mthird\x1b[m\n\x1b[m",
    );

    try expectProcess(
        "\x1b[31ma\n\nb\n",
        3,
        "\x1b[31ma\x1b[m\n\x1b[;31m\x1b[m\n\x1b[;31mb\x1b[m\n\x1b[;31m",
    );
}

fn expectProcess(input: []const u8, chunk_len: usize, expected: []const u8) !void {
    var reader_buffer: [3]u8 = undefined;
    var reader = std.testing.Reader.init(&reader_buffer, &.{.{ .buffer = input }});
    reader.artificial_limit = .limited(chunk_len);

    var output: [1024]u8 = undefined;
    var writer: Io.Writer = .fixed(&output);

    var propagator: Propagator = .{};
    try propagator.process(&reader.interface, &writer);

    try std.testing.expectEqualStrings(expected, writer.buffered());
}

test "every tracked SGR attribute" {
    try expectSgr(
        "\x1b[1;3;4;5;7;8;9;19;31;48;5;200;58;2;1;2;3;51;53;73;60m",
        "\x1b[;1;3;4;5;7;8;9;19;31;48;5;200;58;2;1;2;3;51;53;73;60m",
    );
}

test "bright ANSI colors" {
    try expectSgr(
        "\x1b[97;104m",
        "\x1b[;97;104m",
    );
}

test "RGB color targets" {
    try expectSgr(
        "\x1b[38;2;10;20;30;48;2;40;50;60;58;2;70;80;90m",
        "\x1b[;38;2;10;20;30;48;2;40;50;60;58;2;70;80;90m",
    );
}

test "empty color components" {
    try expectSgr(
        "\x1b[38;5;;48;2;;2;;58;2;1;;3m",
        "\x1b[;38;5;0;48;2;0;2;0;58;2;1;0;3m",
    );
}

test "color override" {
    try expectSgr(
        "\x1b[38;5;17;31;48;2;1;2;3;44;58;2;4;5;6;59m",
        "\x1b[;31;44m",
    );
    try expectSgr(
        "\x1b[31;38;5;17;38;2;1;2;3;44;48;5;18;48;2;4;5;6;58;5;19;58;2;7;8;9m",
        "\x1b[;38;2;1;2;3;48;2;4;5;6;58;2;7;8;9m",
    );
}

test "SGR reset" {
    try expectSgr(
        "\x1b[2;20;21;6;7;8;9;18;90;47;58;5;4;52;53;74;64m" ++
            "\x1b[22;23;24;25;27;28;29;10;39;49;59;54;55;75;65m",
        "\x1b[m",
    );
    try expectSgr("\x1b[1;31m\x1b[0m", "\x1b[m");
}

test "empty SGR parameter" {
    try expectSgr("\x1b[31;;1m", "\x1b[;1m");
    try expectSgr("\x1b[1;31;m", "\x1b[m");
    try expectSgr("\x1b[m", "\x1b[m");
}

test "malformed and incomplete CSI sequences" {
    try expectSgr("\x1b[31x", "\x1b[m");
    try expectSgr("\x1bX\x1b[31m", "\x1b[;31m");
    try expectSgr("\x1b\x1b[31m", "\x1b[;31m");
    try expectSgr("\x1b[38;2;1;2m", "\x1b[m");
    try expectSgr("\x1b[38;4;31m", "\x1b[;4;31m");
}

test "color parameter wrapping" {
    try expectSgr("\x1b[38;999;1m", "\x1b[;1m");
    try expectSgr("\x1b[38;5;300;48;2;999;0;256m", "\x1b[;38;5;44;48;2;231;0;0m");
}

fn expectSgr(input: []const u8, expected: []const u8) !void {
    var propagator: Propagator = .{};
    for (input) |byte| propagator.parseByte(byte);

    var output: [128]u8 = undefined;
    var writer: Io.Writer = .fixed(&output);

    try propagator.writeSgr(&writer);
    try std.testing.expectEqualStrings(expected, writer.buffered());
}

test "fuzz" {
    try std.testing.fuzz({}, fuzz, .{
        .corpus = &.{
            "",
            "\x1b",
            "\x1b[",
            "\x1b[31m\n",
            "\x1b[38;2;1;2;3m\n",
            "\x1b[38;2;255;255;255m\n",
            "\x1b[999999999999m",
        },
    });
}

fn fuzz(_: void, smith: *std.testing.Smith) !void {
    var input_buffer: [256]u8 = undefined;
    const input_len = smith.slice(&input_buffer);

    var reader_buffer: [1]u8 = undefined;
    var reader = std.testing.Reader.init(&reader_buffer, &.{.{ .buffer = input_buffer[0..input_len] }});

    var output_buffer: [32 * 1024]u8 = undefined;
    var writer: Io.Writer = .fixed(&output_buffer);

    var propagator: Propagator = .{};
    try propagator.process(&reader.interface, &writer);
}
