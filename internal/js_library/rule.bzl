load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

JsLibraryInfo = provider(fields=[
  # Path of the BUILD.bazel file relative to the workspace root.
  "build_file_path",
  # Directory containing the JavaScript files (and potentially other assets).
  "full_src_dir",
  # Source files provided as input.
  "javascript_source_files",
  # Other js_library targets depended upon.
  "internal_deps",
  # Depset of npm_packages depended upon (at most one element).
  "npm_packages",
  # Directory in which node_modules/ with external NPM packages can be found.
  "npm_packages_installed_dir",
])

def _js_library_impl(ctx):
  # Ensure that we depend on at most one npm_packages, since we don't want to
  # have conflicting package versions coming from separate node_modules
  # directories.
  direct_npm_packages = [
    dep
    for dep in ctx.attr.deps
    if NpmPackagesInfo in dep
  ]
  if len(direct_npm_packages) > 1:
    fail("Found more than one set of NPM packages in target definition: " + ",".join([
      dep.label
      for dep in direct_npm_packages
    ]))
  extended_npm_packages = depset(
    direct = direct_npm_packages,
    transitive = [
      dep[JsLibraryInfo].npm_packages
      for dep in ctx.attr.deps
      if JsLibraryInfo in dep
    ],
  )
  npm_packages_list = extended_npm_packages.to_list()
  if len(npm_packages_list) > 1:
    fail("Found more than one set of NPM packages through dependencies: " + ",".join([
      dep.label
      for dep in npm_packages_list
    ]))
  # If we depend on an npm_packages target, we'll use its node_modules
  # directory to find modules. Otherwise, we'll use an empty node_modules
  # directory.
  npm_packages = (
    npm_packages_list[0] if len(npm_packages_list) == 1
    else ctx.attr._empty_npm_packages
  )
  # Gather all internal deps (other js_library rules).
  internal_deps = depset(
    direct = [
      dep
      for dep in ctx.attr.deps
      if JsLibraryInfo in dep
    ],
    transitive = [
      dep[JsLibraryInfo].internal_deps
      for dep in ctx.attr.deps
      if JsLibraryInfo in dep
    ],
  )
  # Create a directory that contains:
  # - source files (including all internal dependencies)
  # - node_modules (symlinked to installed external dependencies directory)
  _js_library_create_full_src(
    ctx,
    internal_deps,
    npm_packages,
  )
  _js_library_compile(
    ctx,
    internal_deps,
    npm_packages,
  )
  return [
    JsLibraryInfo(
      build_file_path = ctx.build_file_path,
      full_src_dir = ctx.outputs.compiled_dir,
      javascript_source_files = [_compiled_extension(f.path) for f in ctx.files.srcs],
      internal_deps = internal_deps,
      npm_packages = extended_npm_packages,
      npm_packages_installed_dir = npm_packages[NpmPackagesInfo].installed_dir,
    ),
  ]

def _compiled_extension(path):
  if path.endswith('.es6') or path.endswith('.jsx'):
    return path[:-4] + '.js'
  else:
    return path

def _js_library_create_full_src(ctx, internal_deps, npm_packages):
  ctx.actions.run(
    inputs = [
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.file._js_library_create_full_src_script,
      npm_packages[NpmPackagesInfo].installed_dir,
    ] + [
      d[JsLibraryInfo].full_src_dir
      for d in internal_deps
    ] + ctx.files.srcs,
    outputs = [ctx.outputs.full_src_dir],
    executable = ctx.file._internal_nodejs,
    env = {
      "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules"
    },
    arguments = [
      # Run `node process.js`.
      ctx.file._js_library_create_full_src_script.path,
      # Label of the build target (for helpful errors).
      "//" + npm_packages.label.package + ":" + npm_packages.label.name,
      # Source directories of the js_library targets we depend on.
      ("|".join([
        (";".join(d[JsLibraryInfo].javascript_source_files)) + ":" +
        d[JsLibraryInfo].full_src_dir.path
        for d in internal_deps
      ])),
      # List of source files, which will be processed ("import" statements
      # automatically replaced) and copied into the new directory.
      ("|".join([
        f.path for f in ctx.files.srcs
      ])),
      # Directory in which to place the result.
      ctx.outputs.full_src_dir.path,
    ],
  )

def _js_library_compile(ctx, internal_deps, npm_packages):
  ctx.actions.run(
    inputs = [
      ctx.file._js_library_compile_script,
      ctx.outputs.full_src_dir,
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      npm_packages[NpmPackagesInfo].installed_dir,
    ] + [
      d[JsLibraryInfo].full_src_dir
      for d in internal_deps
    ],
    outputs = [ctx.outputs.compiled_dir],
    executable = ctx.file._internal_nodejs,
    env = {
      "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules"
    },
    arguments = [
      # Run `node js_library/compile.js`.
      ctx.file._js_library_compile_script.path,
      # Directory in which the source code can be found.
      ctx.outputs.full_src_dir.path,
      # Directory in which to output the compiled JavaScript.
      ctx.outputs.compiled_dir.path,
      # List of source files, excluding source files from dependencies.
      ("|".join([
        f.path for f in ctx.files.srcs
      ])),
    ],
  )

js_library = rule(
  implementation=_js_library_impl,
  attrs = {
    "srcs": attr.label_list(
      allow_files = True,
      mandatory = True,
    ),
    "deps": attr.label_list(
      providers = [
        [JsLibraryInfo],
        [NpmPackagesInfo],
      ],
      default = [],
    ),
    "_internal_packages": attr.label(
      default = Label("//internal:packages"),
    ),
    "_internal_nodejs": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("@nodejs//:node"),
    ),
    "_js_library_create_full_src_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/js_library:create_full_src.js"),
    ),
    "_js_library_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/js_library:compile.js"),
    ),
    "_empty_npm_packages": attr.label(
      default = Label("//internal/npm_packages/empty:packages"),
    ),
  },
  outputs = {
    "compiled_dir": "%{name}_compiled",
    "full_src_dir": "%{name}_full_src",
  },
)
