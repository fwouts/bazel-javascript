package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "js_binary")
load("@bazel_typescript//:defs.bzl", "ts_library")

js_binary(
  name = "app",
  lib = ":main",
  entry = "main.js",
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
    "//test/src/nested:constants",
  ]
)
