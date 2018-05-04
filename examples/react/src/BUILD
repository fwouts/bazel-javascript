package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "js_script")
load("@bazel_typescript//:defs.bzl", "ts_library")

js_script(
  name = "storybook-run",
  cmd = "start-storybook -p 9001 -c $LIB_DIR/.storybook",
  lib = ":storybook",
)

ts_library(
  name = "storybook",
  srcs = [
    ".storybook/config.ts",
  ],
  deps = [
    ":component_story",
    "//:packages",
  ],
  requires = [
    "@storybook/react",
    "@types/storybook__react",
  ],
)

ts_library(
  name = "component_story",
  srcs = [
    "component.story.tsx",
  ],
  deps = [
    ":component",
    "//:packages",
  ],
  requires = [
    "@storybook/react",
    "@types/storybook__react",
    "react",
    "@types/react",
  ],
)

ts_library(
  name = "component",
  srcs = [
    "component.tsx",
  ],
  deps = [
    "//:packages",
  ],
  requires = [
    "react",
    "@types/react",
  ]
)
