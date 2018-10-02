# JavaScript and TypeScript rules for Bazel

[![CircleCI](https://circleci.com/gh/zenclabs/bazel-javascript/tree/master.svg?style=svg)](https://circleci.com/gh/zenclabs/bazel-javascript/tree/master)

Consider this beta software. Feel free to report issues and propose improvements!

## Rules

- [js_library](#js_library)
- [web_bundle](#js_binary)
- [js_binary](#js_binary)
- [ts_library](#ts_library)
- [js_script](#js_script)
- [js_test](#js_test)
- [npm_packages](#npm_packages)
- [npm_binary](#npm_binary)

## Overview

If you're not already familiar with [Bazel](https://bazel.build), install it first.

These rules allow you to set up a clean, modular and reusable build infrastructure for your JavaScript and TypeScript code.

Read through an introduction [here](https://docs.google.com/presentation/d/17fQw44C0tzyH8ywWMNmQ4Pvf4Q_pmsjfDYf2MyTKV5I/edit#slide=id.p).

## Installation

First, install [Bazel](https://docs.bazel.build/versions/master/install.html) and [Yarn](https://yarnpkg.com/lang/en/docs/install).

Next, create a `WORKSPACE` file in your project root containing:

```python
# Required for access to js_library, ts_library, js_test, web_bundle, etc.
git_repository(
  name = "bazel_javascript",
  remote = "https://github.com/zenclabs/bazel-javascript.git",
  tag = "0.0.25",
)

# Required for underlying dependencies such as Node and Yarn.
git_repository(
    name = "build_bazel_rules_nodejs",
    remote = "https://github.com/bazelbuild/rules_nodejs.git",
    tag = "0.14.2",
)

# Required by build_bazel_rules_nodejs.
git_repository(
    name = "bazel_skylib",
    remote = "https://github.com/bazelbuild/bazel-skylib.git",
    tag = "0.5.0",
)

load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories")

# By default, the Node and Yarn versions you have installed locally will be
# ignored, and Bazel will install a separate version instead. This helps
# achieve consistency across teams.
#
# See https://github.com/bazelbuild/rules_nodejs if you'd like to use your
# local Node and Yarn binaries instead.
node_repositories(package_json = [])
```

## Basic example

Suppose you have the following directory structure:

```
[workspace]/
  WORKSPACE
  BUILD.bazel
  package.json
  yarn.lock
  src/
    BUILD.bazel
    main.js
    util/
      BUILD.bazel
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

`BUILD.bazel`

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

`src/main.js`

```javascript
import { GREETING } from "./util/constants";

console.log(GREETING);
```

`src/BUILD.bazel`

```python
package(default_visibility = ["//visibility:public"])

load("@bazel_javascript//:defs.bzl", "js_library")

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

`src/util/BUILD.bazel`

```python
package(default_visibility = ["//visibility:public"])

load("@bazel_javascript//:defs.bzl", "js_library")

js_library(
  name = "constants",
  srcs = [
    "constants.js",
  ],
  deps = [
    "//:packages",
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
js_library(
  name,
  srcs,
  deps = [],
)
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
  </tbody>
</table>

### ts_library

```python
ts_library(name, srcs, deps = [], tsconfig = ...)
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

### web_bundle

```python
web_bundle(
  name,
  lib,
  entry,
  html_template,
  mode = "none",
  split_chunks = 0,
  public_path = "",
  library_name = "",
  library_target = "umd",
)
```

Used to compile a `js_library` to a JavaScript bundle to include in an HTML page.

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
    <tr>
      <td><code>output</code></td>
      <td>
        <p>The name of the JS file(s) to generate (optional).</p>
        <p>By default, the name will be <code>bundle.js</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>html_template</code></td>
      <td>
        <p>An HTML file template (optional).</p>
        <p>The generated JavaScript bundle will be injected with a <code>&lt;script&gt;</code> tag.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>mode</code></td>
      <td>
        <p>Configuration mode for webpack (default <code>none</code>).</p>
        <p>
          See <a href="https://webpack.js.org/concepts/mode">Webpack documentation</a> for details.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>split_chunks</code></td>
      <td>
        <p>Whether to split the bundle into chunks.</p>
        <p>
          See <a href="https://webpack.js.org/plugins/split-chunks-plugin/#defaults">Webpack documentation</a> for details.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>public_path</code></td>
      <td>
        <p>Public path where the bundle will be served from (required if <code>split_chunks=1</code>).</p>
        <p>
          For example if your JavaScript files will be served from https://yourdomain.com/js/,
          set <code>public_path</code> to <code>"/js/"</code>.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>library_name</code></td>
      <td>
        <p>The name of a library to generate (optional).</p>
        <p>
          This is only necessary if you're building a JavaScript library to be used by a third-party.
        </p>
        <p>
          See <a href="https://webpack.js.org/configuration/output/#output-library">Webpack documentation</a> for details.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>library_target</code></td>
      <td>
        <p>The type of library to generate (default <code>"umd"</code>). Use along with <code>library_name</code>.</p>
        <p>
          See <a href="https://webpack.js.org/configuration/output/#output-librarytarget">Webpack documentation</a> for details.
        </p>
      </td>
    </tr>
  </tbody>
</table>

### js_binary

Similar to `web_bundle`, but produces an executable JavaScript file (using Node).

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
