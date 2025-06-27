const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "nfde-zig",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const known_folders = b.dependency("known_folders", .{}).module("known-folders");
    lib.root_module.addImport("known-folders", known_folders);

    lib.addIncludePath(b.path("nativefiledialog-extended/src/include/"));

    const build_os = lib.root_module.resolved_target.?.result.os.tag;

    if (build_os == .windows) {
        lib.addCSourceFile(.{
            .file = b.path("nativefiledialog-extended/src/nfd_win.cpp"),
            .language = .cpp,
        });
    } else if (build_os == .macos) {
        lib.linkSystemLibrary("objc");
        lib.linkFramework("Foundation");
        lib.linkFramework("Cocoa");
        lib.linkFramework("AppKit");
        lib.linkFramework("UniformTypeIdentifiers");

        lib.addCSourceFile(.{
            .file = b.path("nativefiledialog-extended/src/nfd_cocoa.m"),
            .language = .objective_c,
        });
    } else {
        const use_portal = b.option(bool, "use-portal", "Use portal for the window backend on Linux instead of GTK.") orelse false;

        const window_backend =
            if (use_portal)
                "nativefiledialog-extended/src/nfd_portal.cpp"
            else
                "nativefiledialog-extended/src/nfd_gtk.cpp";

        lib.addCSourceFile(.{
            .file = b.path(window_backend),
            .language = .cpp,
        });
    }

    b.installArtifact(lib);

    var tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests.step);

    const demo_exe = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("demo/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    demo_exe.root_module.addImport("nfdzig", lib.root_module);

    const demo_install = b.addInstallArtifact(demo_exe, .{});

    const run_demo = b.addRunArtifact(demo_exe);
    run_demo.step.dependOn(&demo_install.step);

    const demo_step = b.step("demo", "Run the demo");
    demo_step.dependOn(&run_demo.step);
}
