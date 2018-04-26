load('//:rules.bzl', 'ts_binary', 'ts_library')

ts_binary(
  name = "app",
  lib = ":main",
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
    "constants.ts",
    "logger.ts",
  ],
)
