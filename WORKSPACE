workspace(name = "bazel_javascript")

git_repository(
    name = "build_bazel_rules_nodejs",
    remote = "https://github.com/bazelbuild/rules_nodejs.git",
    tag = "0.10.0",
)

load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories")

node_repositories(package_json = [])
