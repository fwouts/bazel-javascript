package(default_visibility = ["//visibility:public"])

load('//:rules.bzl', 'npm_package', 'ts_library')

ts_library(
  name = "constants",
  srcs = [
    "constants.ts",
  ],
  deps = [
    ":textbuilder",
  ]
)

npm_package(
  name = "textbuilder",
  package = "textbuilder",
  version = "^1.0.3",
)
