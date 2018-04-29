package(default_visibility = ["//visibility:public"])

load('@bazel_typescript//:defs.bzl', 'npm_binary', 'npm_package')

npm_binary(
  name = "cli",
  package = ":storybook",
  binary = "getstorybook",
)

npm_package(
  name = "storybook",
  package = "@storybook/cli",
  version = "^3.4.2",
)
