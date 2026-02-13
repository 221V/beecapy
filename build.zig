

// https://github.com/capy-ui/zig-template/blob/main/build.zig // todo use capy GUI for v2
// https://github.com/221V/zzz/blob/zig-0.14/build.zig

const std = @import("std");
const builtin = @import("builtin");
//const build_capy = @import("capy");


const zig_version = std.SemanticVersion{ .major = 0, .minor = 14, .patch = 1 };

comptime { // compare zig versions
  const zig_version_eq = zig_version.major == builtin.zig_version.major and
        zig_version.minor == builtin.zig_version.minor and
        zig_version.patch == builtin.zig_version.patch;
  if(!zig_version_eq){
    @compileError(std.fmt.comptimePrint( "unsupported zig version: expected {}, found {}", .{ zig_version, builtin.zig_version } ));
  }
}


pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{}); // target platform
  
  //const optimize = b.standardOptimizeOption(.{}); // -O Debug
  const optimize = std.builtin.OptimizeMode.ReleaseFast; // -O ReleaseFast
  
  //const my_local_lib = b.dependency("my_local_lib", .{
  //  .target = target,
  //  .optimize = optimize,
  //});
  
  //const my_lib_module = my_local_lib.module("my-lib-module");
  //exe_test1.addModule("my-lib", my_lib_module);
  
  
  //const zzz = b.addModule("zzz", .{
    //.root_source_file = b.path("src/lib.zig"),
  //});
  
  const zzz = b.dependency("zzz", .{
    .target = target,
    .optimize = optimize,
  }).module("zzz");
  
  //const capy_dep = b.dependency("capy", .{
  //  .target = target,
  //  .optimize = optimize,
  //  .app_name = @as([]const u8, "beecapy"),
  ////}).module("capy");
  //});
  //const capy = capy_dep.module("capy");
  
  
  //const example1_step = b.step("ex_1", "Build example 1");
  //const example2_step = b.step("ex_2", "Build example 2");
  //const example3_step = b.step("ex_3", "Build example 3");
  //const beecapy_step = b.step("beecapy", "Build program");
  
  
  //const exe_1 = b.addExecutable(.{ // without C libs
  //  .name = "ex_1", // exe name
  //  .root_source_file = b.path("src/example_1.zig"), // b.path("src/test1.zig"), // main file
  //  .target = target,
  //  .optimize = optimize,
  //});
  //const exe_2 = b.addExecutable(.{ // without C libs
  //  .name = "ex_2", // exe name
  //  .root_source_file = b.path("src/example_2.zig"), // main file
  //  .target = target,
  //  .optimize = optimize,
  //});
  //const exe_3 = b.addExecutable(.{ // without C libs
  //  .name = "ex_3", // exe name
  //  .root_source_file = b.path("src/example_3.zig"), // main file
  //  .target = target,
  //  .optimize = optimize,
  //});
  const beecapy_exe = b.addExecutable(.{ // without C libs
    .name = "beecapy", // exe name
    .root_source_file = b.path("src/app.zig"), // main file
    .target = target,
    .optimize = optimize,
  });
  
  //exe_1.root_module.addImport("capy", capy);
  //exe_2.root_module.addImport("capy", capy);
  //exe_3.root_module.addImport("capy", capy);
  //beecapy_exe.root_module.addImport("capy", capy); // todo
  beecapy_exe.root_module.addImport("zzz", zzz);
  //exe_test1.addModule(capy);
  
  //const install_1 = b.addInstallBinFile(exe_1.getEmittedBin(), "../../ex_1"); // b.addInstallBinFile(exe_1.getEmittedBin(), "ex_1"); // -femit-bin=ex_1 // to project root
  //b.getInstallStep().dependOn(&install_1.step);
  //example1_step.dependOn(&install_1.step);
  //const install_2 = b.addInstallBinFile(exe_2.getEmittedBin(), "../../ex_2"); // to project root
  //b.getInstallStep().dependOn(&install_2.step);
  //example2_step.dependOn(&install_2.step);
  //const install_3 = b.addInstallBinFile(exe_3.getEmittedBin(), "../../ex_3"); // to project root
  //b.getInstallStep().dependOn(&install_3.step);
  //example3_step.dependOn(&install_3.step);
  const install_beecapy = b.addInstallBinFile(beecapy_exe.getEmittedBin(), "../../beecapy"); // to project root
  b.getInstallStep().dependOn(&install_beecapy.step);
  //beecapy_step.dependOn(&install_beecapy.step);
  
  b.default_step = b.getInstallStep();
  //b.installArtifact(exe_test1); // saves to /zig-out/bin/test1
  
  
  //const all_examples_step = b.step("examples", "Build all examples");
  //all_examples_step.dependOn(&install_1.step);
  //all_examples_step.dependOn(&install_2.step);
  //all_examples_step.dependOn(&install_3.step);
  
  
  ////exe_test9.root_module.addImport(capy);
  //exe_test9.addModule(capy);
  
  //exe_test9.linkLibC(); // -lc
  
  //exe_test9.addModule("my-lib", my_lib_module);
    
  //b.installArtifact(exe_test9);
  
  
  //const test1_step = b.step("test1", "Build test1 to project root");
  //test1_step.dependOn(&install_test1.step);
  
  //const test9_step = b.step("test9", "Build test9 to project root");
  //test9_step.dependOn(&install_test9.step);
  
  //const run_1 = b.addRunArtifact(exe_1);
  //const run_step_1 = b.step("run-1", "Run example 1 executable");
  //run_step_1.dependOn(&run_1.step);
  
  //const run_test9 = b.addRunArtifact(exe_test9);
  //const run_step_test9 = b.step("run-test9", "Run test9 executable");
  //run_step_test9.dependOn(&run_test9.step);
}

