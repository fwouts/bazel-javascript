package(default_visibility = ["//visibility:public"])

load("//:defs.bzl", "ts_library")

ts_library(
  name = "constants",
  srcs = [
    "constants.ts",
  ],
  deps = [
    ":nodeps",
    "//test/src/testing:sum",
    "//test:packages",
  ],
  requires = [
    "textbuilder",
  ],
  tsconfig = "//test:tsconfig.json",
)

ts_library(
  name = "nodeps",
  srcs = [
    "nodeps.ts",
    "suffix.ts",
  ],
  tsconfig = "//test:tsconfig.json",
)
