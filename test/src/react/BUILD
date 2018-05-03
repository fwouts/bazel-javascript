package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "js_script")
load("@bazel_typescript//:defs.bzl", "ts_library")

js_script(
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
    "//test:packages",
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
    "//test:packages",
  ],
  requires = [
    "@storybook/react",
    "react",
  ],
)

ts_library(
  name = "component",
  srcs = [
    "component1.tsx",
    "component1.css",
    "component2.tsx",
    "component2.css",
  ],
  deps = [
    "//test:packages",
  ],
  requires = [
    "react",
  ]
)
