const std = @import("std");
const simargs = @import("simargs");

const File = std.fs.File;
const FileKind = std.fs.File.Kind;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const FileNode = struct {
    path: []const u8,
    type: std.fs.File.Kind
};

const StowItem = struct {
    path: []const u8,
    type: std.fs.File.Kind,
};

const L = std.TailQueue(*FileNode);

pub const std_options = struct {
    pub const log_level: std.log.Level = .info;
};

const arg_options = struct {
    verbose: ?bool = false,
    folder: []const u8 = "./",

    pub const __shorts__ = .{
        .verbose = .v,
        .folder = .f,
    };

    pub const __messages__ = .{
        .verbose = "Make the operation more talkative",
        .folder = "The source folder to symlink to the destination",
    };
};

fn createNode(allocator: Allocator, path: []u8, kind: FileKind) !*L.Node {
    const childFn: *FileNode = try allocator.create(FileNode);
    childFn.path = path;
    childFn.type = kind;
    
    var childNode = try allocator.create(L.Node);
    childNode.data = childFn;
    return childNode;
}

fn expandTree(allocator: Allocator, node: *L.Node) !ArrayList(*L.Node) {
    var path = node.data.path;
    var kind = node.data.type;

    std.debug.print(
        \\checking if node exists:
        \\  node: {*}
        \\  data: {*}
        \\  path: {*}
        \\  path(value): {s}
        \\
        ,.{
        node,
        &node.data,
        path,
        path,
    });

    var nodes = ArrayList(*L.Node).init(allocator);
    if (kind == std.fs.File.Kind.Directory) {
        std.debug.print("node is a directory: {s}...\n", .{ path });
        var d = try std.fs.openDirAbsolute(path, .{});
        defer d.close();
        var iterableDir = try d.makeOpenPathIterable("./", .{}); 
        var it = iterableDir.iterate();
        while (try it.next()) |file| {
            const paths = &[_][]const u8{ path, file.name };
            const fullPath = try std.fs.path.join(allocator, paths);
            const childNode = try createNode(allocator, fullPath, file.kind);

            std.debug.print(
                \\prepending node:
                \\  path:{s}
                \\  node:{*}
                \\
            , .{ fullPath, childNode });

            try nodes.append(childNode);
        }
    } else {
        std.debug.print("node is not a directory: {s}...\n", .{ path });
    }

    return nodes;
}

fn createFileList(allocator: Allocator, rootPath: []const u8) !ArrayList(StowItem) {
    std.debug.print("creating fileList...\n", .{});
    var items = ArrayList(StowItem).init(allocator);
    var queue = L{};
    const allocRootPath = try std.fmt.allocPrint(allocator, "{s}", .{ rootPath });
    const rootNode = try createNode(allocator, allocRootPath, FileKind.Directory);

    queue.append(rootNode);
    std.debug.print("appended root...\n", .{});

    while (queue.popFirst()) |node| {
        std.debug.print("queue count: {d}\n", .{ queue.len });
        const childNodes: ArrayList(*L.Node) = try expandTree(allocator, node);
        defer childNodes.deinit();
        for (childNodes.items) |childNode| {
            queue.append(childNode);
 
            var path = try std.fmt.allocPrint(allocator, "{s}", .{ childNode.data.path });
            var stowItem = StowItem{
                .path = path,
                .type = childNode.data.type,
            };
            try items.append(stowItem);
        }
        allocator.destroy(node.data.path);
        allocator.destroy(node.data);
        allocator.destroy(node);
    }

    return items;
}

pub fn main() !void {
    std.debug.print("starting...\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit()) {
        std.debug.print("allocator has leaks\n", .{});
    };

    var opt = try simargs.parse(allocator, arg_options);
    defer opt.deinit();

    const args = opt.args;

    const folder = if (!std.fs.path.isAbsolute(args.folder))
        try std.fs.cwd().realpathAlloc(allocator, args.folder)
    else
        try std.fmt.allocPrint(allocator, "{s}", .{ args.folder });
 
    defer allocator.free(folder);

    const items: ArrayList(StowItem) = try createFileList(
        allocator, folder
    );
    defer items.deinit();

    for (items.items) |item| {
        std.debug.print("{s}\n", .{ item.path });
        allocator.destroy(item.path);
    }
    std.debug.print("done.\n", .{});
}

test "list files from folder with depth of 1" {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer gpa.deinit();

    // TODO: create tmp directory and files

    const items = try createFileList(allocator, "/home/hr/tmp");
    for (items) |item| {
        std.debug.print("{s}", .{ item.path });
    }
}
