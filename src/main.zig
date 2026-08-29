const std = @import("std");
const config = @import("config");

const Answer = enum { uppercase, lowercase, none };

const Mode = enum {
    poweroff,
    reboot,

    fn path(self: Mode) []const u8 {
        return switch (self) {
            .poweroff => config.poweroff_path,
            .reboot => config.reboot_path,
        };
    }

    fn desc(self: Mode) []const u8 {
        return switch (self) {
            .poweroff => "shut down",
            .reboot => "reboot",
        };
    }
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    const mode: Mode =
        if (args.len == 2 and std.mem.eql(u8, args[1], "-r"))
            .reboot
        else
            .poweroff;

    if (!try std.Io.File.stdout().isTty(init.io))
        return doExec(init.io, mode);

    var inbuf: [1024]u8 = undefined;
    var inreader = std.Io.File.stdin().reader(init.io, &inbuf);
    const stdin = &inreader.interface;

    var outbuf: [1024]u8 = undefined;
    var outreader = std.Io.File.stdout().writer(init.io, &outbuf);
    const stdout = &outreader.interface;

    var hostname_buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const hostname: []const u8 =
        std.posix.gethostname(&hostname_buf) catch "this host";

    try stdout.writeAll(
        \\
        \\######## ATTENTION, DIPSHIT ########
        \\
    );
    try stdout.print(
        "You are about to {s} {s}!\n",
        .{ mode.desc(), hostname },
    );
    try stdout.writeAll(
        \\Are you REALLY sure about this?
        \\Type yes in UPPERCASE and press enter to confirm: 
    );
    try stdout.flush();

    var fucked_up: bool = false;

    while (true) {
        switch (try getConfirmation(stdin, stdout)) {
            .uppercase => return countdown(init.io, mode, stdout),

            .lowercase => {
                if (!fucked_up) {
                    fucked_up = true;
                    try stdout.writeAll(
                        "How hard can it be? UPPERCASE YOU MAGGOT! Try again: ",
                    );
                    try stdout.flush();
                } else {
                    try stdout.writeAll("Go fuck yourself\n");
                    try stdout.flush();
                    return;
                }
            },

            .none => {
                try stdout.writeAll("That's what I thought.\n");
                try stdout.flush();
                return;
            },
        }
    }
}

fn getConfirmation(stdin: *std.Io.Reader, stdout: *std.Io.Writer) !Answer {
    const input = try stdin.takeDelimiter('\n') orelse {
        try stdout.writeAll("\n");
        try stdout.flush();
        return .none;
    };

    if (std.mem.eql(u8, input, "YES"))
        return .uppercase;

    if (std.ascii.eqlIgnoreCase(input, "yes"))
        return .lowercase;

    return .none;
}

fn countdown(io: std.Io, mode: Mode, stdout: *std.Io.Writer) !void {
    try stdout.print("Alright, {s} in ", .{mode.desc()});

    for (0..10) |i| {
        try stdout.print("{d}\n", .{10 - i});
        try stdout.flush();
        io.sleep(.fromSeconds(1), .awake) catch return;
    }

    return doExec(io, mode);
}

fn doExec(io: std.Io, mode: Mode) !void {
    const path = mode.path();

    return std.process.replace(
        io,
        .{
            .argv = &.{path},
        },
    );
}
