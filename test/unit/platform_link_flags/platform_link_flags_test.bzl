"""Unittest to verify deduplicated platform link args"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_shared_library")
load("//test/unit:common.bzl", "assert_action_mnemonic")

def _platform_link_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    argv = action.argv
    assert_action_mnemonic(env, action, "Rustc")

    # check that lpthread appears just once
    if "--target=x86_64-unknown-linux-gnu" in action.argv:
        for flag in action.argv:
            if flag.startswith("link-args="):
                asserts.true(
                    env,
                    flag.count("-lpthread") == 1,
                    "Expected link-args to contain '-lpthread' once.",
                )

    return analysistest.end(env)

platform_link_flags_test = analysistest.make(_platform_link_flags_test_impl)

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

    rust_shared_library(
        name = "library_cdylib",
        srcs = ["cdylib.rs"],
        crate_root = "cdylib.rs",
        deps = [
            ":library_one",
            ":library_two",
            ":library_three",
        ],
    )

    rust_binary(
        name = "binary",
        srcs = ["main.rs"],
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

    platform_link_flags_test(
        name = "platform_link_flags_rust_binary_test",
        target_under_test = ":binary",
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
            ":platform_link_flags_rust_binary_test",
        ],
    )
