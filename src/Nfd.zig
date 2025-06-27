const std = @import("std");
const Allocator = std.mem.Allocator;
const Arraylist = std.ArrayList;

const kf = @import("known-folders");

const nfd = @cImport(@cInclude("nfd.h"));

const Self = @This();

pub const NFDError = error{ Error, OutOfMemory };

pub const NFDResult = enum {
    okay,
    cancel,

    fn from_nfdresult(nfdresult: nfd.nfdresult_t) NFDError!NFDResult {
        return switch (nfdresult) {
            nfd.NFD_OKAY => .okay,
            nfd.NFD_CANCEL => .cancel,
            else => error.Error,
        };
    }
};

pub const NFDFilter = struct {
    name: []const u8,
    filter: []const u8,
};

pub const NFDOpenOptions = struct {
    default_path: ?[]const u8 = null,
    filters: []NFDFilter = &.{},
};

pub fn DialogResult(comptime T: type) type {
    return struct {
        selected: T,
        kind: NFDResult,
    };
}

pub const SingleDialogResult = DialogResult([]const u8);

allocator: Allocator,
alloc_filter: ?[]NFDFilter = null,
strings: Arraylist([]const u8),
nfdstrings: Arraylist([*c]u8),
should_free_nfdstrings: bool = false,

pub fn init(allocator: Allocator) NFDError!Self {
    const result = nfd.NFD_Init();
    _ = try NFDResult.from_nfdresult(result);

    return .{
        .allocator = allocator,
        .strings = Arraylist([]const u8).init(allocator),
        .nfdstrings = Arraylist([*c]u8).init(allocator),
    };
}

pub fn open(self: *Self, options: NFDOpenOptions) !SingleDialogResult {
    var filters = self.allocator.alloc(nfd.nfdfilteritem_t, options.filters.len) catch {
        return error.OutOfMemory;
    };
    defer self.allocator.free(filters);

    //

    for (options.filters, 0..) |f, i| {
        filters[i] = .{
            .name = f.name.ptr,
            .spec = f.filter.ptr,
        };
    }

    const default_path =
        if (options.default_path) |path|
            path
        else
            try kf.getPath(self.allocator, .home) orelse @panic("home folder does not exist");

    var output = [_]u8{0};
    var output_slice = &output;

    const result = nfd.NFD_OpenDialogU8(@ptrCast(&output_slice), filters.ptr, @intCast(filters.len), default_path.ptr);
    const kind = try NFDResult.from_nfdresult(result);
    self.should_free_nfdstrings = kind == .okay;

    return .{
        .selected = &output,
        .kind = kind,
    };
}

pub fn getError() [*:0]const u8 {
    return nfd.NFD_GetError();
}

pub fn deinit(self: *Self) void {
    nfd.NFD_Quit();
    nfd.NFD_ClearError();

    if (self.alloc_filter) |filter|
        self.allocator.free(filter);

    for (self.strings.items) |string| {
        self.allocator.free(string);
    }

    if (self.should_free_nfdstrings) {
        for (self.nfdstrings.items) |nfdstring| {
            nfd.NFD_FreePath(nfdstring);
        }
    }

    self.strings.deinit();
    self.nfdstrings.deinit();
}
