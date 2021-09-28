"""Unittest to verify deduplicated platform link args"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_shared_library")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_argv_contains")

def _is_running_on_linux(ctx):
    return ctx.target_platform_has_constraint(ctx.attr._linux[platform_common.ConstraintValueInfo])

def _check_for_link_flag(env, ctx, action):
    if not _is_running_on_linux(ctx):
        return True

    for flag in action.argv:
        if flag.startswith("link-args="):
            # check that lpthread appears just once
            asserts.true(
                env,
                flag.count("-lpthread") == 1,
                "Expected link-args to contain '-lpthread' once.",
            )

            # check that -l flags added by crates below appear first
            if flag.count("-lc") == 1 and flag.count("-lrt") == 1:
                asserts.true(
                    env,
                    flag.index("-lc") < flag.index("-ldl -lpthread") and flag.index("-lrt") < flag.index("-ldl -lpthread"),
                    "Expected crate link arguments to appear first",
                )
            return True
    return False

def _platform_link_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    argv = action.argv
    assert_action_mnemonic(env, action, "Rustc")
    asserts.true(env, _check_for_link_flag(env, ctx, action))
    return analysistest.end(env)

platform_link_flags_test = analysistest.make(_platform_link_flags_test_impl, attrs = {
    "_linux": attr.label(default = Label("@platforms//os:linux")),
})

def _platform_link_flags_test():
    cc_library(
        name = "linkopts_native_dep_a",
        srcs = ["native_dep.cc"],
        linkopts = selects.with_or({
            (
                "@rules_rust//rust/platform:i686-unknown-linux-gnu",
                "@rules_rust//rust/platform:x86_64-unknown-linux-gnu",
                "@rules_rust//rust/platform:aarch64-unknown-linux-gnu",
            ): [
                "-lc",
            ],
            "//conditions:default": [],
        }),
        deps = [":linkopts_native_dep_b"],
    )

    cc_library(
        name = "linkopts_native_dep_b",
        linkopts = selects.with_or({
            (
                "@rules_rust//rust/platform:i686-unknown-linux-gnu",
                "@rules_rust//rust/platform:x86_64-unknown-linux-gnu",
                "@rules_rust//rust/platform:aarch64-unknown-linux-gnu",
            ): [
                "-lrt",
            ],
            "//conditions:default": [],
        }),
    )

    rust_binary(
        name = "linkopts_rust_bin",
        srcs = ["bin_using_native_dep.rs"],
        deps = [":linkopts_native_dep_a"],
    )

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

    rust_binary(
        name = "binary_with_no_deps",
        srcs = ["main.rs"],
    )

    platform_link_flags_test(
        name = "platform_link_flags_test",
        target_under_test = ":library_cdylib",
    )

    platform_link_flags_test(
        name = "platform_link_flags_rust_binary_test",
        target_under_test = ":binary",
    )

    platform_link_flags_test(
        name = "platform_link_flags_rust_binary_no_deps_test",
        target_under_test = ":binary_with_no_deps",
    )

    platform_link_flags_test(
        name = "platform_link_flags_rust_binary_native_deps_test",
        target_under_test = ":linkopts_rust_bin",
    )

def _check_cpp_link_flags(env, ctx, tut):
    if not _is_running_on_linux(ctx):
        return True

    for action in tut.actions:
        if action.mnemonic == "CppLink":
            assert_argv_contains(env, action, "-ldl")
            assert_argv_contains(env, action, "-lpthread")
            return True
    return False

def _platform_link_flags_cc_binary_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    _check_cpp_link_flags(env, ctx, tut)
    return analysistest.end(env)

platform_link_flags_cc_binary_test = analysistest.make(_platform_link_flags_cc_binary_test_impl, attrs = {
    "_linux": attr.label(default = Label("@platforms//os:linux")),
})

def _platform_link_flags_cc_binary_test():
    rust_library(
        name = "library_one_for_cc",
        srcs = ["library_one.rs"],
    )

    rust_library(
        name = "library_two_for_cc",
        srcs = ["library_two.rs"],
    )

    rust_library(
        name = "library_three_for_cc",
        srcs = ["library_three.rs"],
    )

    cc_binary(
        name = "cc_binary",
        srcs = ["main.cc"],
        deps = [
            ":library_one_for_cc",
            ":library_two_for_cc",
            ":library_three_for_cc",
        ],
    )

    platform_link_flags_cc_binary_test(
        name = "platform_link_flags_cc_binary_test",
        target_under_test = ":cc_binary",
    )

def platform_link_flags_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _platform_link_flags_test()
    _platform_link_flags_cc_binary_test()

    native.test_suite(
        name = name,
        tests = [
            ":platform_link_flags_test",
            ":platform_link_flags_rust_binary_test",
            ":platform_link_flags_rust_binary_no_deps_test",
            ":platform_link_flags_rust_binary_native_deps_test",
            ":platform_link_flags_cc_binary_test",
        ],
    )
