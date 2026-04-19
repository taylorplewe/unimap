const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dvui_dep = b.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .dx11 });

    const exe = b.addExecutable(.{
        .name = "unimap",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "dvui", .module = dvui_dep.module("dvui_dx11") },
                .{ .name = "dvui-backend", .module = dvui_dep.module("dx11") }, // for zls
            },
        }),
    });

    b.installArtifact(exe);
}
