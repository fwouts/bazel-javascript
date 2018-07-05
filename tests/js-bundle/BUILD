package(default_visibility = ["//visibility:public"])

load("@bazel_javascript//:defs.bzl", "web_bundle")

web_bundle(
  name = "bundle",
  lib = "//tests/js-bundle/src:main",
  entry = "main.js",
  target = "node"
)
