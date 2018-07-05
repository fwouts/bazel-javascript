package(default_visibility = ["//visibility:public"])

load("@bazel_javascript//:defs.bzl", "js_test")
load("@bazel_typescript//:defs.bzl", "ts_library")

ts_library(
  name = "sum",
  srcs = [
    "sum.ts",
  ],
)

ts_library(
  name = "sum_test_lib",
  srcs = [
    "sum.spec.ts",
  ],
  deps = [
    "//test:packages",
    ":sum",
  ],
  requires = [
    "jest",
    "@types/jest",
  ],
)

js_test(
  name = "sum_test",
  cmd = "jest sum.spec.js",
  lib = ":sum_test_lib",
)
