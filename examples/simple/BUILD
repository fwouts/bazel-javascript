package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "npm_packages")
load("@bazel_typescript//:defs.bzl", "ts_binary")

ts_binary(
  name = "app",
  lib = "//src:main",
  entry = "main.js",
)

npm_packages(
  name = "packages",
  package_json = ":package.json",
  yarn_lock = ":yarn.lock",
)
