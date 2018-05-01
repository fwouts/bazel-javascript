# Produced by ts_library().
TsLibraryInfo = provider(fields=[
  # Directory containing the compiled JavaScript and TypeScript definitions.
  "compiled_dir",
  # Directory containing the TypeScript files used for compilation.
  "full_src_dir",
  # Source files provided as input.
  "srcs",
  # Other ts_library targets depended upon.
  "internal_deps",
  # Depset of npm_packages depended upon (at most one element).
  "npm_packages",
  # Directory in which node_modules/ with external NPM packages can be found.
  "npm_packages_installed_dir",
])

# Produced by npm_packages().
NpmPackagesInfo = provider(fields=[
  "installed_dir",
])

def _ts_library_impl(ctx):
  # Ensure that we depend on at most one npm_packages, since we don't want to
  # have conflicting package versions coming from separate node_modules
  # directories.
  extended_npm_packages = depset(
    direct = [
      dep
      for dep in ctx.attr.deps
      if NpmPackagesInfo in dep
    ],
    transitive = [
      dep[TsLibraryInfo].npm_packages
      for dep in ctx.attr.deps
      if TsLibraryInfo in dep
    ],
  )
  npm_packages_list = extended_npm_packages.to_list()
  if len(npm_packages_list) > 1:
    fail("Found more than one set of NPM packages: " + ",".join([
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
      if TsLibraryInfo in dep
    ],
    transitive = [
      dep[TsLibraryInfo].internal_deps
      for dep in ctx.attr.deps
      if TsLibraryInfo in dep
    ],
  )
  # Create a directory that contains:
  # - source files
  # - tsconfig.json
  # - node_modules/@types
  # - node_modules/[name] for every internal dep
  #
  # Note that node_modules/ will not contain external dependencies from NPM.
  # Instead, the tsconfig.json will point to the node_modules/ directory of
  # the npm_packages target we depend on. This means we don't have to lose
  # performance by copy-pasting node_modules with hundreds of packages.
  _ts_library_create_full_src(
    ctx,
    internal_deps,
    npm_packages,
    ctx.attr.requires,
  )
  # Compile the directory with `tsc`.
  _ts_library_compile(
    ctx,
    npm_packages,
  )
  return [
    TsLibraryInfo(
      srcs = [f.path for f in ctx.files.srcs],
      compiled_dir = ctx.outputs.compiled_dir,
      full_src_dir = ctx.outputs.full_src_dir,
      internal_deps = internal_deps,
      npm_packages = extended_npm_packages,
      npm_packages_installed_dir = npm_packages[NpmPackagesInfo].installed_dir,
    ),
  ]

def _ts_library_create_full_src(ctx, internal_deps, npm_packages, requires):
  ctx.actions.run_shell(
    inputs = [
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.file._ts_library_create_full_src_script,
      npm_packages[NpmPackagesInfo].installed_dir,
    ] + [
      d[TsLibraryInfo].compiled_dir
      for d in internal_deps
    ] + ctx.files.srcs,
    outputs = [ctx.outputs.full_src_dir],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node create_full_src.js`.
      ctx.file._ts_library_create_full_src_script.path,
      # Directory containing node_modules/ with all external NPM packages
      # installed.
      npm_packages[NpmPackagesInfo].installed_dir.path,
      # BUILD file path, necessary to understand relative "import" statements
      # in TypeScript.
      ctx.build_file_path,
      # List of NPM package names used by the source files.
      ("|".join([
        p
        for p in requires
      ])),
      # List of ts_library targets we depend on, along with their source files
      # (required to replace relative "import" statements with the correct
      # module name).
      ("|".join([
        d.label.package + ':' +
        d.label.name + ':' +
        (";".join(d[TsLibraryInfo].srcs)) + ":" +
        d[TsLibraryInfo].compiled_dir.path
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

def _ts_library_compile(ctx, npm_packages):
  ctx.actions.run_shell(
    inputs = [
      ctx.file._ts_library_compile_script,
      ctx.outputs.full_src_dir,
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
      ctx.outputs.full_src_dir.path,
      # Directory in which to generate the compiled JavaScript and TypeScript
      # definitions.
      ctx.outputs.compiled_dir.path,
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
        [TsLibraryInfo],
        [NpmPackagesInfo],
      ],
      default = [],
    ),
    "requires": attr.string_list(
      default = [],
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
    "_empty_npm_packages": attr.label(
      default = Label("//internal/npm_packages/empty:packages"),
    ),
  },
  outputs = {
    "compiled_dir": "%{name}_compiled",
    "full_src_dir": "%{name}_full_src",
  },
)

def _ts_script_impl(ctx):
  # Ensure that we depend on at most one npm_packages, since we don't want to
  # have conflicting package versions coming from separate node_modules
  # directories.
  extended_npm_packages = depset(
    direct = [
      dep
      for dep in ctx.attr.deps
      if NpmPackagesInfo in dep
    ],
    transitive = [
      dep[TsLibraryInfo].npm_packages
      for dep in ctx.attr.deps
      if TsLibraryInfo in dep
    ],
  )
  npm_packages_list = extended_npm_packages.to_list()
  if len(npm_packages_list) > 1:
    fail("Found more than one set of NPM packages: " + ",".join([
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
  runfiles = ctx.runfiles(
    files = [
      npm_packages[NpmPackagesInfo].installed_dir,
      ctx.outputs.full_src_dir,
    ],
  )
  # Gather all internal deps (ts_library rules we depend on).
  internal_deps = depset(
    direct = [
      dep
      for dep in ctx.attr.deps
      if TsLibraryInfo in dep
    ],
    transitive = [
      dep[TsLibraryInfo].internal_deps
      for dep in ctx.attr.deps
      if TsLibraryInfo in dep
    ],
  )
  # Create a directory that contains:
  # - source files
  # - package.json with {
  #     "scripts": {
  #       "start": "[cmd]"
  #     }
  #   }
  # - node_modules/[name] for every internal dep
  #
  # Note that node_modules/ will not contain external dependencies from NPM.
  # Instead, the tsconfig.json will point to the node_modules/ directory of
  # the npm_packages target we depend on. This means we don't have to lose
  # performance by copy-pasting node_modules with hundreds of packages.
  #
  # Also generate a shell script that will run `yarn start`.
  ctx.actions.run_shell(
    inputs = [
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      npm_packages[NpmPackagesInfo].installed_dir,
    ] + [
      d[TsLibraryInfo].compiled_dir
      for d in internal_deps
    ] + ctx.files.srcs + ctx.files._ts_script_compile_script,
    outputs = [
      ctx.outputs.full_src_dir,
      ctx.outputs.executable_file,
    ],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node ts_script/compile.js`.
      ctx.file._ts_script_compile_script.path,
      # The command to run.
      ctx.attr.cmd,
      # Directory containing node_modules/ with all external NPM packages
      # installed.
      npm_packages[NpmPackagesInfo].installed_dir.path,
      # Same path required in short form for the shell script.
      npm_packages[NpmPackagesInfo].installed_dir.short_path,
      # BUILD file path, necessary to know where to put the source files.
      ctx.build_file_path,
      # List of source files to copy (which will not be compiled by tsc).
      ("|".join([f.path for f in ctx.files.srcs])),
      # List of ts_library targets we depend on, along with their compiled
      # JavaScript and TypeScript definitions.
      ("|".join([
        d.label.package + ':' +
        d.label.name + ':' +
        d[TsLibraryInfo].compiled_dir.path
        for d in internal_deps
      ])),
      # Directory in which to create package.json and copy sources.
      ctx.outputs.full_src_dir.path,
      # Same path required in short form for the shell script.
      ctx.outputs.full_src_dir.short_path,
      # Path to generate the shell script.
      ctx.outputs.executable_file.path,
    ],
  )
  return [
    DefaultInfo(
      executable = ctx.outputs.executable_file,
      runfiles = runfiles,
    ),
  ]

ts_script = rule(
  implementation = _ts_script_impl,
  attrs = {
    "cmd": attr.string(),
    "srcs": attr.label_list(
      allow_files = True,
      default = [],
    ),
    "deps": attr.label_list(
      providers = [
        [TsLibraryInfo],
        [NpmPackagesInfo],
      ],
    ),
    "_internal_packages": attr.label(
      default = Label("//internal:packages"),
    ),
    "_ts_script_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/ts_script:compile.js"),
    ),
  },
  executable = True,
  outputs = {
    "full_src_dir": "%{name}_full_src",
    "executable_file": "%{name}.sh",
  },
)

def _ts_binary_impl(ctx):
  # Create a directory containing the webpack config.
  build_dir = ctx.actions.declare_directory(ctx.label.name + "_build_dir")
  ctx.actions.run_shell(
    inputs = [
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.attr._webpack_npm_packages[NpmPackagesInfo].installed_dir,
      ctx.attr.lib[TsLibraryInfo].npm_packages_installed_dir,
      ctx.attr.lib[TsLibraryInfo].full_src_dir,
    ] + ctx.files._ts_binary_compile_script,
    outputs = [
      build_dir,
      ctx.outputs.executable_file,
    ],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node ts_binary/compile.js`.
      ctx.file._ts_binary_compile_script.path,
      # Entry point for Webpack (e.g. "main.ts").
      ctx.attr.entry,
      # Directory containing webpack, webpack-cli, typescript and ts-loader.
      ctx.attr._webpack_npm_packages[NpmPackagesInfo].installed_dir.path,
      # Directory containing external NPM dependencies the code depends on.
      ctx.attr.lib[TsLibraryInfo].npm_packages_installed_dir.path,
      # Directory containing the source code of the ts_library.
      ctx.attr.lib[TsLibraryInfo].full_src_dir.path,
      # Directory in which to place the webpack config.
      build_dir.path,
      # Directory in which to place the compiled JavaScript.
      ctx.outputs.executable_file.path,
    ],
  )
  return [
    DefaultInfo(
      executable = ctx.outputs.executable_file,
    ),
  ]

ts_binary = rule(
  implementation=_ts_binary_impl,
  attrs = {
    "lib": attr.label(
      providers = [TsLibraryInfo],
    ),
    "entry": attr.string(),
    "_internal_packages": attr.label(
      default = Label("//internal:packages"),
    ),
    "_ts_binary_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/ts_binary:compile.js"),
    ),
    "_webpack_npm_packages": attr.label(
      default = Label("//internal/ts_binary/webpack:packages"),
    ),
  },
  executable = True,
  outputs = {
    "executable_file": "%{name}.js",
  },
)

def _npm_packages_impl(ctx):
  ctx.actions.run_shell(
    inputs = [
      ctx.file._npm_packages_install,
      ctx.file.package_json,
      ctx.file.yarn_lock,
    ],
    outputs = [ctx.outputs.installed_dir],
    command = "node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node npm_packages/install.js`.
      ctx.file._npm_packages_install.path,
      # Path of package.json to install with.
      ctx.file.package_json.path,
      # Path of yarn.lock to lock versions.
      ctx.file.yarn_lock.path,
      # Path to install into (node_modules/ will be created there).
      ctx.outputs.installed_dir.path,
    ],
  )
  return [
    NpmPackagesInfo(
      installed_dir = ctx.outputs.installed_dir
    ),
  ]

npm_packages = rule(
  implementation = _npm_packages_impl,
  attrs = {
    "package_json": attr.label(
      allow_files = True,
      single_file = True,
    ),
    "yarn_lock": attr.label(
      allow_files = True,
      single_file = True,
    ),
    "_npm_packages_install": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/npm_packages:install.js"),
    ),
  },
  outputs = {
    "installed_dir": "%{name}_installed_dir",
  },
)

def _npm_binary_impl(ctx):
  # Generate a simple shell script that starts the binary, loaded from the
  # node_modules/.bin directory.
  ctx.actions.write(
    output = ctx.outputs.bin,
    content = "%s/node_modules/.bin/%s" % (
      ctx.attr.install[NpmPackagesInfo].installed_dir.short_path,
      ctx.attr.binary,
    ),
    is_executable = True,
  )
  return [
    DefaultInfo(
      runfiles = ctx.runfiles(
        files = [
          ctx.attr.install[NpmPackagesInfo].installed_dir,
        ],
      ),
      executable = ctx.outputs.bin,
    )
  ]

npm_binary = rule(
  implementation = _npm_binary_impl,
  attrs = {
    "install": attr.label(
      providers = [NpmPackagesInfo],
    ),
    "binary": attr.string(),
  },
  outputs = {
    "bin": "%{name}.sh"
  },
  executable = True,
)
