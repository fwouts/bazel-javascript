package(default_visibility = ["//visibility:public"])

load('@bazel_typescript//:defs.bzl', 'ts_library')

ts_library(
  name = "constants",
  srcs = [
    "constants.ts",
  ],
  deps = [
    ":nodeps",
    "//test:packages",
  ],
  requires = [
    "textbuilder",
  ],
)

ts_library(
  name = "nodeps",
  srcs = [
    "nodeps.ts",
  ],
)
