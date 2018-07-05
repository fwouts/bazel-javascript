package(default_visibility = ["//visibility:public"])

load("@bazel_javascript//:defs.bzl", "npm_packages")

npm_packages(
  name = "packages",
  package_json = ":package.json",
  yarn_lock = ":yarn.lock",
)

exports_files([
  "tsconfig.json",
])
