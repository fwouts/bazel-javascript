package(default_visibility = ["//visibility:public"])

load('@bazel_typescript//:defs.bzl', 'ts_binary', 'ts_library')

ts_binary(
  name = "app",
  lib = ":main",
  entry = "main.ts",
)

ts_library(
  name = "main",
  srcs = [
    "main.ts",
  ],
  deps = [
    ":logger",
  ]
)

ts_library(
  name = "logger",
  srcs = [
    "logger.ts",
  ],
  deps = [
    "//example/src/nested:constants",
  ]
)
