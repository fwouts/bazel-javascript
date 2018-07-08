package(default_visibility = ["//visibility:public"])

load("@bazel_javascript//:defs.bzl", "npm_packages", "js_binary")

js_binary(
  name = "app",
  lib = "//src:main",
  entry = "main.js",
)

npm_packages(
  name = "packages",
  package_json = ":package.json",
  yarn_lock = ":yarn.lock",
)
