load("@bazel_javascript//:defs.bzl", "JsLibraryInfo", "NpmPackagesInfo")

TsLibraryInfo = provider(fields=[
  # Directory containing the generated TypeScript definitions and compiled JavaScript.
  "compiled_src_dir",
])

def _ts_library_impl(ctx):
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
  if len(direct_npm_packages) == 0 and len(ctx.attr.requires) > 0:
    fail("ts_library requires packages but does not depend on an npm_packages target.")
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
  # Gather all internal deps (other ts_library rules).
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

  # Create two directories that contain:
  # - source files (including all internal dependencies)
  # - node_modules (symlinked to installed external dependencies directory)

  # First version includes all dependencies' TypeScript definitions, which
  # requires compiling everything up the tree (slow). Necessary to be able
  # to compile TypeScript, including type verification.
  _ts_library_create_full_src(
    ctx,
    internal_deps,
    npm_packages,
    ctx.outputs.compilation_src_dir,
    True,
  )

  # Second version only includes dependencies' transpiled JavaScript code,
  # which is a lot faster but does not do any type checking.
  _ts_library_create_full_src(
    ctx,
    internal_deps,
    npm_packages,
    ctx.outputs.transpilation_src_dir,
    False,
  )

  # Compile the directory with `tsc` (slower but stricter).
  _ts_library_compile(
    ctx,
    npm_packages,
  )

  # Transpile the directory with `tsc` (faster, no type checking).
  _ts_library_transpile(
    ctx,
    npm_packages,
  )

  return [
    JsLibraryInfo(
      build_file_path = ctx.build_file_path,
      srcs = [f.path for f in ctx.files.srcs],
      full_src_dir = ctx.outputs.transpiled_dir,
      internal_deps = internal_deps,
      npm_packages = extended_npm_packages,
      npm_packages_installed_dir = npm_packages[NpmPackagesInfo].installed_dir,
    ),
    TsLibraryInfo(
      compiled_src_dir = ctx.outputs.compiled_dir,
    ),
  ]

def _ts_library_create_full_src(ctx, internal_deps, npm_packages, output_dir, for_compilation):
  ctx.actions.run_shell(
    inputs = [
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.file._ts_library_create_full_src_script,
      npm_packages[NpmPackagesInfo].installed_dir,
      ctx.file.tsconfig,
    ] + [
      d[TsLibraryInfo].compiled_src_dir
      if for_compilation and TsLibraryInfo in d
      else d[JsLibraryInfo].full_src_dir
      for d in internal_deps
    ] + ctx.files.srcs,
    outputs = [output_dir],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node create_full_src.js`.
      ctx.file._ts_library_create_full_src_script.path,
      # Label of the build target (for helpful errors).
      "//" + ctx.label.package + ":" + ctx.label.name,
      # Label of the package.json target (for helpful errors).
      "//" + npm_packages.label.package + ":" + npm_packages.label.name,
      # Directory containing node_modules/ with all external NPM packages
      # installed.
      npm_packages[NpmPackagesInfo].installed_dir.path,
      # BUILD file path
      ctx.build_file_path,
      # tsconfig.json path.
      ctx.file.tsconfig.path,
      # List of NPM package names used by the source files.
      ("|".join([
        p
        for p in ctx.attr.requires
      ])),
      # Source directories of the ts_library targets we depend on.
      ("|".join([
        (";".join(d[JsLibraryInfo].srcs)) + ":" +
        (
          d[TsLibraryInfo].compiled_src_dir.path
          if for_compilation and TsLibraryInfo in d
          else d[JsLibraryInfo].full_src_dir.path
        )
        for d in internal_deps
      ])),
      # List of source files, which will be processed ("import" statements
      # automatically replaced) and copied into the new directory.
      ("|".join([
        f.path for f in ctx.files.srcs
      ])),
      # Directory in which to place the result.
      output_dir.path,
    ],
  )

def _ts_library_compile(ctx, npm_packages):
  ctx.actions.run_shell(
    inputs = [
      ctx.file._ts_library_compile_script,
      ctx.outputs.compilation_src_dir,
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      npm_packages[NpmPackagesInfo].installed_dir,
    ],
    outputs = [ctx.outputs.compiled_dir],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node ts_library/compile.js`.
      ctx.file._ts_library_compile_script.path,
      # Directory in which the source code as well as tsconfig.json can be found.
      ctx.outputs.compilation_src_dir.path,
      # Directory in which to generate the compiled JavaScript and TypeScript
      # definitions.
      ctx.outputs.compiled_dir.path,
    ],
  )

def _ts_library_transpile(ctx, npm_packages):
  ctx.actions.run_shell(
    inputs = [
      ctx.file._ts_library_transpile_script,
      ctx.outputs.transpilation_src_dir,
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      npm_packages[NpmPackagesInfo].installed_dir,
    ],
    outputs = [ctx.outputs.transpiled_dir],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node ts_library/transpile.js`.
      ctx.file._ts_library_transpile_script.path,
      # Directory in which the source code as well as tsconfig.json can be found.
      ctx.outputs.transpilation_src_dir.path,
      # Directory in which to generate the transpiled JavaScript and TypeScript
      # definitions.
      ctx.outputs.transpiled_dir.path,
    ],
  )

ts_library = rule(
  implementation=_ts_library_impl,
  attrs = {
    "srcs": attr.label_list(
      allow_files = True,
    ),
    "deps": attr.label_list(
      providers = [
        [JsLibraryInfo],
        [NpmPackagesInfo],
      ],
      default = [],
    ),
    "requires": attr.string_list(
      default = [],
    ),
    "tsconfig": attr.label(
      allow_files = [".json"],
      single_file = True,
      default = Label("//internal/ts_library:default_tsconfig.json"),
    ),
    "_internal_packages": attr.label(
      default = Label("//internal:packages"),
    ),
    "_ts_library_create_full_src_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/ts_library:create_full_src.js"),
    ),
    "_ts_library_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/ts_library:compile.js"),
    ),
    "_ts_library_transpile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/ts_library:transpile.js"),
    ),
    "_empty_npm_packages": attr.label(
      default = Label("@bazel_javascript//internal/npm_packages/empty:packages"),
    ),
  },
  outputs = {
    "compilation_src_dir": "%{name}_compilation_src",
    "compiled_dir": "%{name}_compiled",
    "transpilation_src_dir": "%{name}_transpilation_src",
    "transpiled_dir": "%{name}_transpiled",
  },
)
