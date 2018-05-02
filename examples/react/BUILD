package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "npm_packages", "npm_binary")

npm_packages(
  name = "packages",
  package_json = ":package.json",
  yarn_lock = ":yarn.lock",
)

npm_binary(
  name = "cli",
  install = "//:packages",
  binary = "getstorybook",
)
