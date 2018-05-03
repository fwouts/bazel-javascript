# Node rules for Bazel [alpha]

## Rules

- [js_library](#js_library)
- [js_bundle](#js_binary)
- [js_binary](#js_binary)
- [js_script](#js_script)
- [js_test](#js_test)
- [npm_packages](#npm_packages)
- [npm_binary](#npm_binary)

## Overview

If you're not already familiar with [Bazel](https://bazel.build), install it first.

These Node rules for Bazel are separate from the [official Google
implementation](https://github.com/bazelbuild/rules_nodejs).

## Installation

First, install [Bazel](https://docs.bazel.build/versions/master/install.html) and [Yarn](https://yarnpkg.com/lang/en/docs/install).

Next, create a `WORKSPACE` file in your project root containing:

```python
git_repository(
  name = "bazel_node",
  remote = "https://github.com/zenclabs/bazel-node.git",
  tag = "0.0.10", # check for the latest tag when you install
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
    main.js
    util/
      BUILD
      constants.js
```

`package.json`

```json
{
  "dependencies": {
    "textbuilder": "^1.0.3"
  }
}
```

`BUILD`

```python
package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "js_binary", "npm_packages")

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

`src/main.js`

```javascript
import { GREETING } from "./util/constants";

console.log(GREETING);
```

`src/BUILD`

```python
package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "js_library")

js_library(
  name = "main",
  srcs = [
    "main.js",
  ],
  deps = [
    "//src/util:constants",
  ],
)
```

`src/util/constants.js`

```javascript
import TextBuilder from "textbuilder";

const t = new TextBuilder();
t.append("Hello ", process.argv[2] || "Daniel");
export const GREETING = t.build();
```

`src/util/BUILD`

```python
package(default_visibility = ["//visibility:public"])

load("@bazel_node//:defs.bzl", "js_library")

js_library(
  name = "constants",
  srcs = [
    "constants.js",
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

### js_library

```python
js_library(name, srcs, deps = [], requires = [], tsconfig = ...)
```

Used to represent a set of JavaScript files and their dependencies.

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
        <p>You may include non-JavaScript files, which will be copy-pasted as is.</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <p>A list of labels (optional).</p>
        <p>
          This could be any other <code>js_library</code> targets, or at most one <code>npm_packages</code> target.
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
  </tbody>
</table>

### js_bundle

```python
js_bundle(name, lib, entry)
```

Used to compile a `js_library` to a single JavaScript bundle file.

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
        <p>A <code>js_library</code> target (required).</p>
      </td>
    </tr>
    <tr>
      <td><code>entry</code></td>
      <td>
        <p>The path of the entrypoint within the <code>js_library</code> target (required).</p>
        <p>
          For example if the <code>js_library</code> includes a single file <code>main.js</code>,
          entry should be set to <code>"main.js"</code>.
        </p>
      </td>
    </tr>
  </tbody>
</table>

### js_binary

Identical to `js_bundle`, but produces an executable JavaScript file (using Node).

### js_script

```python
js_script(cmd, lib)
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
        <p>A <code>js_library</code> target (required).</p>
        <p>The script will execute in the target's compiled directory.</p>
      </td>
    </tr>
  </tbody>
</table>

### js_test

```python
js_test(cmd, lib)
```

Used to define a test. Arguments are identical to `js_script`.

### npm_packages

```python
npm_packages(name, package_json, yarn_lock)
```

Used to define NPM dependencies. Bazel will download the packages in its own internal directory.

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
      <td><code>package_json</code></td>
      <td>
        <p>A package.json file (required).</p>
      </td>
    </tr>
    <tr>
      <td><code>yarn_lock</code></td>
      <td>
        <p>A yarn.lock file (required).</p>
      </td>
    </tr>
  </tbody>
</table>

### npm_binary

```python
npm_binary(install, binary)
```

Used to invoke an NPM binary (from `node_modules/.bin/[binary]`).

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
      <td><code>install</code></td>
      <td>
        <p>An <code>npm_packages</code> target (required).</p>
      </td>
    </tr>
    <tr>
      <td><code>binary</code></td>
      <td>
        <p>The name of the binary to execute (required).</p>
      </td>
    </tr>
  </tbody>
</table>
