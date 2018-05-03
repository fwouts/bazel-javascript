package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "js_library", "npm_packages")

npm_packages(
  name = "packages",
  package_json = ":package.json",
  yarn_lock = ":yarn.lock",
)

js_library(
  name = "a",
  srcs = [
    "a.js",
  ],
)
