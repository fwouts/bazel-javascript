package(default_visibility = ["//visibility:public"])

load('@bazel_typescript//:defs.bzl', 'ts_library', 'ts_script')

ts_script(
  name = "storybook",
  cmd = "start-storybook -p 9001 -c .storybook",
  srcs = [
    ".storybook/config.js",
  ],
  deps = [
    ":component_story",
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
  ]
)

ts_library(
  name = "component",
  srcs = [
    "component.tsx",
  ],
  deps = [
    "//test:packages",
  ],
  requires = [
    "react",
  ]
)
