package(default_visibility = ["//visibility:public"])

load("@bazel_typescript//:defs.bzl", "ts_library", "ts_script")

ts_script(
  name = "storybook-run",
  cmd = "start-storybook -p 9001 -c .storybook",
  lib = ":storybook",
)

ts_library(
  name = "storybook",
  srcs = [
    ".storybook/config.js",
  ],
  deps = [
    ":component_story",
    "//:packages",
  ],
  requires = [
    "@storybook/react",
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
    "react",
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
  ]
)
