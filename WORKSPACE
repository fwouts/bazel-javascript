workspace(name = "bazel_javascript")

git_repository(
    name = "build_bazel_rules_nodejs",
    remote = "https://github.com/bazelbuild/rules_nodejs.git",
    tag = "0.14.2",
)

load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories")

node_repositories(package_json = [])

# See https://github.com/bazelbuild/bazel/issues/2460#issuecomment-362284757
local_repository(
  name = "ignore_examples",
  path = "./examples",
)
