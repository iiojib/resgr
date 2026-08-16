const Sgr = @This();

const std = @import("std");

intensity: ?Intensity = null,
italic: ?Italic = null,
underline: ?Underline = null,
blink: ?Blink = null,
inverse: ?bool = null,
concealed: ?bool = null,
crossed_out: ?bool = null,
font: ?Font = null,
foreground: ?Color = null,
background: ?Color = null,
underline_color: ?Color = null,
framing: ?Framing = null,
overline: ?bool = null,
script: ?Script = null,
ideogram: ?Ideogram = null,

pub fn default() Sgr {
    return .{
        .intensity = .normal,
        .italic = .none,
        .underline = .none,
        .blink = .none,
        .inverse = false,
        .concealed = false,
        .crossed_out = false,
        .font = .default,
        .foreground = .default,
        .background = .default,
        .underline_color = .default,
        .framing = .none,
        .overline = false,
        .script = .none,
        .ideogram = .none,
    };
}

pub fn apply(self: *Sgr, other: *const Sgr) void {
    if (other.intensity) |intensity| self.intensity = if (intensity == .normal) null else intensity;
    if (other.italic) |italic| self.italic = if (italic == .none) null else italic;
    if (other.underline) |underline| self.underline = if (underline == .none) null else underline;
    if (other.blink) |blink| self.blink = if (blink == .none) null else blink;
    if (other.inverse) |inverse| self.inverse = if (inverse == false) null else inverse;
    if (other.concealed) |concealed| self.concealed = if (concealed == false) null else concealed;
    if (other.crossed_out) |crossed_out| self.crossed_out = if (crossed_out == false) null else crossed_out;
    if (other.font) |font| self.font = if (font == .default) null else font;
    if (other.foreground) |foreground| self.foreground = if (foreground == .default) null else foreground;
    if (other.background) |background| self.background = if (background == .default) null else background;
    if (other.underline_color) |underline_color| self.underline_color = if (underline_color == .default) null else underline_color;
    if (other.framing) |framing| self.framing = if (framing == .none) null else framing;
    if (other.overline) |overline| self.overline = if (overline == false) null else overline;
    if (other.script) |script| self.script = if (script == .none) null else script;
    if (other.ideogram) |ideogram| self.ideogram = if (ideogram == .none) null else ideogram;
}

pub const Intensity = enum {
    normal,
    bold,
    faint,

    pub fn fromCode(code: u8) ?Intensity {
        return switch (code) {
            1 => .bold,
            2 => .faint,
            22 => .normal,
            else => null,
        };
    }

    pub fn toCode(self: Intensity) u8 {
        return switch (self) {
            .normal => 22,
            .bold => 1,
            .faint => 2,
        };
    }
};

pub const Italic = enum {
    none,
    italic,
    fraktur,

    pub fn fromCode(code: u8) ?Italic {
        return switch (code) {
            3 => .italic,
            20 => .fraktur,
            23 => .none,
            else => null,
        };
    }

    pub fn toCode(self: Italic) u8 {
        return switch (self) {
            .none => 23,
            .italic => 3,
            .fraktur => 20,
        };
    }
};

pub const Underline = enum {
    none,
    single,
    double,

    pub fn fromCode(code: u8) ?Underline {
        return switch (code) {
            4 => .single,
            21 => .double,
            24 => .none,
            else => null,
        };
    }

    pub fn toCode(self: Underline) u8 {
        return switch (self) {
            .none => 24,
            .single => 4,
            .double => 21,
        };
    }
};

pub const Blink = enum {
    none,
    slow,
    rapid,

    pub fn fromCode(code: u8) ?Blink {
        return switch (code) {
            5 => .slow,
            6 => .rapid,
            25 => .none,
            else => null,
        };
    }

    pub fn toCode(self: Blink) u8 {
        return switch (self) {
            .none => 25,
            .slow => 5,
            .rapid => 6,
        };
    }
};

pub const Font = enum(u4) {
    default,
    _,

    pub fn fromCode(code: u8) ?Font {
        return switch (code) {
            10...19 => @enumFromInt(code - 10),
            else => null,
        };
    }

    pub fn toCode(self: Font) u8 {
        return switch (@intFromEnum(self)) {
            0...9 => |val| @as(u8, @intCast(val)) + 10,
            else => unreachable,
        };
    }
};

pub const Framing = enum {
    none,
    framed,
    encircled,

    pub fn fromCode(code: u8) ?Framing {
        return switch (code) {
            51 => .framed,
            52 => .encircled,
            54 => .none,
            else => null,
        };
    }

    pub fn toCode(self: Framing) u8 {
        return switch (self) {
            .none => 54,
            .framed => 51,
            .encircled => 52,
        };
    }
};

pub const Script = enum {
    none,
    superscript,
    subscript,

    pub fn fromCode(code: u8) ?Script {
        return switch (code) {
            73 => .superscript,
            74 => .subscript,
            75 => .none,
            else => null,
        };
    }

    pub fn toCode(self: Script) u8 {
        return switch (self) {
            .none => 75,
            .superscript => 73,
            .subscript => 74,
        };
    }
};

pub const Ideogram = enum {
    none,
    underline,
    double_underline,
    overline,
    double_overline,
    stress_marking,

    pub fn fromCode(code: u8) ?Ideogram {
        return switch (code) {
            60 => .underline,
            61 => .double_underline,
            62 => .overline,
            63 => .double_overline,
            64 => .stress_marking,
            65 => .none,
            else => null,
        };
    }

    pub fn toCode(self: Ideogram) u8 {
        return switch (self) {
            .none => 65,
            .underline => 60,
            .double_underline => 61,
            .overline => 62,
            .double_overline => 63,
            .stress_marking => 64,
        };
    }
};

pub const ColorTarget = enum {
    foreground,
    background,
    underline,

    pub fn fromCode(code: u8) ?ColorTarget {
        return switch (code) {
            38 => .foreground,
            48 => .background,
            58 => .underline,
            else => null,
        };
    }

    pub fn toCode(self: ColorTarget) u8 {
        return switch (self) {
            .foreground => 38,
            .background => 48,
            .underline => 58,
        };
    }
};

pub const Color = union(enum) {
    default,
    ansi: Ansi,
    indexed: u8,
    rgb: [3]u8,

    pub fn fromCode(code: u8) ?Color {
        if (Ansi.fromCode(code)) |ansi| return .{ .ansi = ansi };
        return null;
    }

    pub fn fromIndex(index: u8) Color {
        return .{ .indexed = index };
    }

    pub fn fromBytes(bytes: [3]u8) Color {
        return .{ .rgb = bytes };
    }

    pub const Ansi = enum(u4) {
        _,

        pub fn fromCode(code: u8) ?Ansi {
            return switch (code) {
                30...37 => @enumFromInt(code - 30),
                90...97 => @enumFromInt(code - 90 + 8),
                40...47 => @enumFromInt(code - 40),
                100...107 => @enumFromInt(code - 100 + 8),
                else => null,
            };
        }

        pub fn toCode(self: Ansi, target: ColorTarget) u8 {
            return switch (target) {
                .foreground => switch (@intFromEnum(self)) {
                    0...7 => |val| @as(u8, @intCast(val)) + 30,
                    8...15 => |val| @as(u8, @intCast(val)) - 8 + 90,
                },

                .background => switch (@intFromEnum(self)) {
                    0...7 => |val| @as(u8, @intCast(val)) + 40,
                    8...15 => |val| @as(u8, @intCast(val)) - 8 + 100,
                },

                .underline => unreachable,
            };
        }
    };
};

test "apply overrides" {
    var sgr: Sgr = .{
        .intensity = .bold,
        .foreground = .fromCode(1),
        .background = .fromIndex(17),
    };

    sgr.apply(&.{
        .intensity = .faint,
        .italic = .italic,
        .foreground = .fromBytes(.{ 1, 2, 3 }),
    });

    try std.testing.expectEqual(Intensity.faint, sgr.intensity);
    try std.testing.expectEqual(Italic.italic, sgr.italic);
    try std.testing.expectEqual(Color.fromBytes(.{ 1, 2, 3 }), sgr.foreground);
    try std.testing.expectEqual(Color.fromIndex(17), sgr.background);
}

test "apply defaults" {
    var sgr: Sgr = .{
        .intensity = .bold,
        .italic = .italic,
        .underline = .single,
        .blink = .slow,
        .inverse = true,
        .concealed = true,
        .crossed_out = true,
        .font = .fromCode(1),
        .foreground = .fromCode(1),
        .background = .fromIndex(17),
        .underline_color = .fromBytes(.{ 1, 2, 3 }),
        .framing = .framed,
        .overline = true,
        .script = .superscript,
        .ideogram = .underline,
    };

    sgr.apply(&.default());

    try std.testing.expectEqual(Sgr{}, sgr);
}
