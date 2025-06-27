# nfde-zig

A wrapper around the [nativefiledialog-extended](https://github.com/btzy/nativefiledialog-extended) library.

## Installation

Install the library with `zig fetch --save git+https://github.com/voidwyrm-2/nfde-zig`.

## Example

```zig
const std = @import("std");
const Nfd = @import("nfdzig").Nfd;

pub fn main() !u8 {
    var fd = Nfd.init(std.heap.page_allocator) catch |err| {
        if (err == Nfd.NFDError.Error) {
            std.debug.print("error from NFD: {s}\n", .{Nfd.getError()});
            return 1;
        }

        return err;
    };
    defer fd.deinit();

    var filters = [_]Nfd.NFDFilter{
        .{
            .name = "Windows executables",
            .filter = "exe",
        },
        .{
            .name = "C source files",
            .filter = "c",
        },
    };

    const result = try fd.open(.{
        .filters = &filters,
    });

    switch (result.kind) {
        .okay => std.debug.print("selected {s}\n", .{result.selected}),
        .cancel => std.debug.print("canceled\n", .{}),
    }

    return 0;
}
```
