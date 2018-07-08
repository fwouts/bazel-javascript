# TypeScript rules for Bazel

[![CircleCI](https://circleci.com/gh/zenclabs/bazel-typescript.svg?style=svg)](https://circleci.com/gh/zenclabs/bazel-typescript)

## Rules

- [ts_library](#ts_library)

Also makes use of rules from [bazel-javascript](https://github.com/zenclabs/bazel-javascript):
- [js_binary](https://github.com/zenclabs/bazel-javascript#js_binary)
- [js_script](https://github.com/zenclabs/bazel-javascript#js_script)
- [js_test](https://github.com/zenclabs/bazel-javascript#js_test)
- [npm_packages](https://github.com/zenclabs/bazel-javascript#npm_packages)
- [npm_binary](https://github.com/zenclabs/bazel-javascript#npm_binary)

## Overview

If you're not already familiar with [Bazel](https://bazel.build), install it first.

These TypeScript rules for Bazel are separate from the [official Google
implementation](https://github.com/bazelbuild/rules_typescript).

## Installation

First, install [Bazel](https://docs.bazel.build/versions/master/install.html) and [Yarn](https://yarnpkg.com/lang/en/docs/install).

Next, create a `WORKSPACE` file in your project root containing:

```python
git_repository(
  name = "bazel_typescript",
  remote = "https://github.com/zenclabs/bazel-typescript.git",
  tag = "0.0.25",
)

git_repository(
  name = "bazel_javascript",
  remote = "https://github.com/zenclabs/bazel-javascript.git",
  tag = "0.0.16",
)
```

## Basic example

Suppose you have the following directory structure:

```
[workspace]/
  WORKSPACE
  BUILD
  package.json
  yarn.lock
  src/
    BUILD
    main.ts
    util/
      BUILD
      constants.ts
```

`package.json`

```json
{
  "dependencies": {
    "textbuilder": "^1.0.3"
  },
  "devDependencies": {
    "@types/node": "^8.10.11"
  }
}
```

`BUILD`

```python
package(default_visibility = ["//visibility:public"])

load("@bazel_javascript//:defs.bzl", "js_binary", "npm_packages")

js_binary(
  name = "app",
  lib = "//src:main",
  entry = "main.js",
)

npm_packages(
  name = "packages",
  package_json = ":package.json",
  yarn_lock = ":yarn.lock",
)
```

`src/main.ts`

```typescript
import { GREETING } from "./util/constants";

console.log(GREETING);
```

`src/BUILD`

```python
package(default_visibility = ["//visibility:public"])

load("@bazel_typescript//:defs.bzl", "ts_library")

ts_library(
  name = "main",
  srcs = [
    "main.ts",
  ],
  deps = [
    "//src/util:constants",
  ],
)
```

`src/util/constants.ts`

```typescript
import TextBuilder from "textbuilder";

const t = new TextBuilder();
t.append("Hello ", process.argv[2] || "Daniel");
export const GREETING = t.build();
```

`src/util/BUILD`

```python
package(default_visibility = ["//visibility:public"])

load("@bazel_typescript//:defs.bzl", "ts_library")

ts_library(
  name = "constants",
  srcs = [
    "constants.ts",
  ],
  deps = [
    "//:packages",
  ],
  requires = [
    "textbuilder",
  ],
)
```

Run and build the binary:
```sh
$ bazel run //:app John
INFO: Analysed target //:app (0 packages loaded).
INFO: Found 1 target...
Target //:app up-to-date:
  bazel-bin/app.js
INFO: Elapsed time: 0.140s, Critical Path: 0.00s
INFO: Build completed successfully, 1 total action

INFO: Running command line: bazel-bin/app.js John
Hello John
```

## Rules

### ts_library

```python
ts_library(name, srcs, deps = [], requires = [], tsconfig = ...)
```

Used to generate the compiled JavaScript and declaration files for a set of
TypeScript source files.

<table>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p>A unique name for this rule (required).</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <p>A list of source files (required).</p>
        <p>You may include non-TypeScript files, which will be copy-pasted as is.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p>A list of labels (optional).</p>
        <p>
          This could be any other <code>ts_library</code> targets, or at most one <code>npm_packages</code> target.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>requires</code></td>
      <td>
        <p>A list of required NPM module names (optional).</p>
        <p>
          This must include any NPM module that the source files directly depend on.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>tsconfig</code></td>
      <td>
        <p>A custom TypeScript config file (optional).</p>
        <p>
          Only compiler options will be used. Some options such as
          <code>paths</code> will be overridden.
        </p>
      </td>
    </tr>
  </tbody>
</table>
