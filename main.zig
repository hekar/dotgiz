const std = @import("std");

const FileNode = struct {
    path: []u8,
};

pub fn main() !void {
    const root = "/home/hr/dotfiles";
    const queue = std.TailQueue(FileNode);
    queue.prepend(FileNode{
        .path = root,
    });
    while (queue.pop()) |node| {
        const data = node.data;
        std.fs.accessAbsolute(data.path) catch |err| {
            if (err) {
                continue;
            }
        };

        const f = try std.fs.openFileAbsolute(data.path);
        defer f.close();
        const stat = try f.stat();
        if (stat.kind == std.fs.File.Kind.Directory) {
            std.os.
            const d = try std.fs.openDirAbsolute();
        }
    }
    const path = "";
    std.fs.accessAbsolute(path);
    const stdout = std.io.getStdOut().writer();
    var i: usize = 1;
    while (i <= 16) : (i += 1) {
        if (i % 15 == 0) {
            try stdout.writeAll("ZiggZagg\n");
        } else if (i % 3 == 0) {
            try stdout.writeAll("Zigg\n");
        } else if (i % 5 == 0) {
            try stdout.writeAll("Zagg\n");
        } else {
            try stdout.print("{d}\n", .{i});
        }
    }
}