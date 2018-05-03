# TypeScript rules for Bazel [alpha]

## Rules

- [ts_library](#ts_library)
- [ts_binary](#ts_binary)
- [ts_script](#ts_script)
- [ts_test](#ts_test)

## Overview

If you're not already familiar with [Bazel](https://bazel.build), install it first.

These TypeScript rules for Bazel are separate from the [official Google
implementation](https://github.com/bazelbuild/rules_typescript).

The main differences are:

- Easier setup ([literally eight lines](examples/simple/WORKSPACE)).
- No need for a `node_modules` directory.
- You must specify a `yarn.lock` along with `package.json`.

As of 1 May 2018, a few key features are missing:
- compiling JS bundles ([#22](https://github.com/zenclabs/bazel-typescript/issues/22))
- support for asset bundling ([#16](https://github.com/zenclabs/bazel-typescript/issues/16))
- live reloading ([#23](https://github.com/zenclabs/bazel-typescript/issues/23))
- automatic BUILD file generation ([#24](https://github.com/zenclabs/bazel-typescript/issues/24))

## Installation

First, install [Bazel](https://docs.bazel.build/versions/master/install.html) and [Yarn](https://yarnpkg.com/lang/en/docs/install).

Next, create a `WORKSPACE` file in your project root containing:

```python
git_repository(
  name = "bazel_typescript",
  remote = "https://github.com/zenclabs/bazel-typescript.git",
  tag = "0.0.18", # check for the latest tag when you install
)

git_repository(
  name = "bazel_node",
  remote = "https://github.com/zenclabs/bazel-node.git",
  tag = "0.0.8", # check for the latest tag when you install
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

load("@bazel_node//:defs.bzl", "npm_packages")
load("@bazel_typescript//:defs.bzl", "ts_binary")

ts_binary(
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

### ts_binary

```python
ts_binary(name, lib, entry)
```

Used to compile a `ts_library` to a single JavaScript file.

Note: for now, the generated file is targeted for Node ([see issue](https://github.com/zenclabs/bazel-typescript/issues/22)).

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
      <td><code>lib</code></td>
      <td>
        <p>A <code>ts_library</code> target (required).</p>
      </td>
    </tr>
    <tr>
      <td><code>entry</code></td>
      <td>
        <p>The path of the entrypoint within the <code>ts_library</code> target (required).</p>
        <p>
          For example if the <code>ts_library</code> includes a single file <code>main.ts</code>,
          entry should be set to <code>"main.js"</code> (note that it's the compiled version).
        </p>
      </td>
    </tr>
  </tbody>
</table>

### ts_script

```python
ts_script(cmd, lib)
```

Used to run a script (similarly to `scripts` in `package.json`).

<table>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>cmd</code></td>
      <td>
        <p>The command to run (required).</p>
      </td>
    </tr>
    <tr>
      <td><code>lib</code></td>
      <td>
        <p>A <code>ts_library</code> target (required).</p>
        <p>The script will execute in the target's compiled directory.</p>
      </td>
    </tr>
  </tbody>
</table>

### ts_test

```python
ts_test(cmd, lib)
```

Used to define a test. Arguments are identical to `ts_script`.
