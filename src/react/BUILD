package(default_visibility = ["//visibility:public"])

load('//:defs.bzl', 'npm_package', 'ts_library', 'ts_script')

ts_script(
  name = "storybook",
  cmd = "start-storybook -p 9001 -c .storybook",
  srcs = [
    ".storybook/config.js",
  ],
  deps = [
    ":component_story",
    ":babel-core",
    ":react-dom",
  ],
)

ts_library(
  name = "component_story",
  srcs = [
    "component.story.tsx",
  ],
  deps = [
    ":component",
    ":storybook_react",
    ":storybook_react_types",
    ":react",
    ":react_types",
  ]
)

ts_library(
  name = "component",
  srcs = [
    "component.tsx",
  ],
  deps = [
    ":react",
    ":react_types",
  ]
)

npm_package(
  name = "storybook_react",
  package = "@storybook/react",
  version = "^3.4.2",
)

npm_package(
  name = "storybook_react_types",
  package = "@types/storybook__react",
  version = "^3.0.7",
)

npm_package(
  name = "react",
  package = "react",
  version = "^16.0.0",
)

npm_package(
  name = "react_types",
  package = "@types/react",
  version = "^16.0.0",
)

npm_package(
  name = "react-dom",
  package = "react-dom",
  version = "^16.0.0",
)

npm_package(
  name = "babel-core",
  package = "babel-core",
  version = "^6.26.2",
)
