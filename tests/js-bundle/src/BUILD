package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "js_library")

js_library(
  name = "main",
  srcs = [
    "main.js",
  ],
  deps = [
    "//tests/js-library-complex/nested:combined",
  ],
)
