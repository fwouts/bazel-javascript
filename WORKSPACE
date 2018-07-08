workspace(name = "bazel_typescript")

git_repository(
  name = "bazel_javascript",
  remote = "https://github.com/zenclabs/bazel-javascript.git",
  tag = "0.0.17",
)

# local_repository(
#   name = "bazel_javascript",
#   path = "../bazel-javascript",
# )

git_repository(
    name = "build_bazel_rules_nodejs",
    remote = "https://github.com/bazelbuild/rules_nodejs.git",
    tag = "0.10.0",
)

load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories")

node_repositories(package_json = [])
