# We depend on the NodeJS rules to load Node, Yarn and TSC.
# TODO: Consider removing such dependencies.

git_repository(
    name = "build_bazel_rules_nodejs",
    remote = "https://github.com/bazelbuild/rules_nodejs.git",
    tag = "0.7.0",
)

load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories")

node_repositories(package_json = ["//:bazel_package.json"])
