"""Unittest to verify location expansion in rustc flags"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//rust:rust.bzl", "rust_library")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_argv_contains")

def _cdylib_platform_link_flags_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    argv = action.argv
    assert_action_mnemonic(env, action, "Rustc")
    if "--target=x86_64-unknown-linux-gnu" in action.argv:
        assert_argv_contains(env, action, "link-args=-fuse-ld=gold -Wl,-no-as-needed -Wl,-z,relro,-z,now -B/usr/bin -pass-exit-codes -ldl -lpthread -lstdc++ -lm")
    return analysistest.end(env)

platform_link_flags_test = analysistest.make(_cdylib_platform_link_flags_test)

def _platform_link_flags_test():
    rust_library(
        name = "library_one",
        srcs = ["library_one.rs"],
    )

    rust_library(
        name = "library_two",
        srcs = ["library_two.rs"],
    )

    rust_library(
        name = "library_three",
        srcs = ["library_three.rs"],
    )

    rust_library(
        name = "library_cdylib",
        srcs = ["cdylib.rs"],
        crate_root = "cdylib.rs",
        crate_type = "cdylib",
        deps = [
            ":library_one",
            ":library_two",
            ":library_three",
        ],
    )

    platform_link_flags_test(
        name = "platform_link_flags_test",
        target_under_test = ":library_cdylib",
    )

def platform_link_flags_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _platform_link_flags_test()

    native.test_suite(
        name = name,
        tests = [
            ":platform_link_flags_test",
        ],
    )
