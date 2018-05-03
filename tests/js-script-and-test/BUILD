package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "js_library", "js_script", "js_test")

# This is a script, producing an executable (bazel run).
js_script(
  name = "script",
  lib = ":lib",
  cmd = "jest",
)

# This is a script, producing a test (bazel test).
js_test(
  name = "test",
  lib = ":lib",
  cmd = "jest",
)

js_library(
  name = "lib",
  srcs = [
    "example.spec.js",
  ],
  deps = [
    "//tests/js-library-complex/nested:combined",
  ],
)
