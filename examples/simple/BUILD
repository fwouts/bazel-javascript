package(default_visibility = ["//visibility:public"])

load("@bazel_typescript//:defs.bzl", "npm_packages", "ts_binary")

ts_binary(
  name = "app",
  lib = "//src:main",
  entry = "main.ts",
)

npm_packages(
  name = "packages",
  package_json = ":package.json",
  yarn_lock = ":yarn.lock",
)
