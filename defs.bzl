TsLibraryInfo = provider(fields=[
  "compiled_dir",
  "full_src_dir",
  "srcs",
  "internal_deps",
  "npm_packages",
  "npm_packages_installed_dir",
])
NpmPackagesInfo = provider(fields=[
  "installed_dir",
])

def _ts_library_create_full_src(ctx, internal_deps, npm_packages, requires):
  ctx.actions.run(
    inputs = [
      ctx.executable._yarn,
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.file._ts_library_create_full_src_script,
    ] + [
      d[TsLibraryInfo].compiled_dir
      for d in internal_deps
    ] + ctx.files.srcs + (
      [npm_packages[NpmPackagesInfo].installed_dir] if npm_packages
      else []
    ),
    outputs = [ctx.outputs.full_src_dir],
    executable = ctx.executable._node,
    env = {
      "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + '/node_modules',
    },
    arguments = [
      ctx.file._ts_library_create_full_src_script.path,
      ctx.executable._yarn.path,
      npm_packages[NpmPackagesInfo].installed_dir.path if npm_packages else ctx.outputs.full_src_dir.path,
      ctx.build_file_path,
      ("|".join([
        p
        for p in requires
      ])),
      ("|".join([
        d.label.package + ':' +
        d.label.name + ':' +
        ("|".join(d[TsLibraryInfo].srcs)) + ":" +
        d[TsLibraryInfo].compiled_dir.path
        for d in internal_deps
      ])),
      ("|".join([
        f.path for f in ctx.files.srcs
      ])),
      ctx.outputs.full_src_dir.path,
    ],
  )

def _ts_library_compile(ctx, npm_packages):
  ctx.actions.run(
    inputs = [
      ctx.outputs.full_src_dir,
    ] + (
      [npm_packages[NpmPackagesInfo].installed_dir] if npm_packages
      else []
    ),
    outputs = [ctx.outputs.compiled_dir],
    executable = ctx.executable._tsc,
    arguments = [
      "--project",
      ctx.outputs.full_src_dir.path,
      "--outDir",
      ctx.outputs.compiled_dir.path,
    ],
  )

def _ts_library_impl(ctx):
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
  npm_packages = (
    npm_packages_list[0] if len(npm_packages_list) == 1
    else ctx.attr._empty_npm_packages
  )
  _ts_library_create_full_src(
    ctx,
    internal_deps,
    npm_packages,
    ctx.attr.requires,
  )
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

ts_library = rule(
  implementation=_ts_library_impl,
  attrs = {
    "srcs": attr.label_list(
      allow_files=[".ts", ".tsx"],
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
    "_node": attr.label(
      allow_files = True,
      executable = True,
      cfg = "host",
      default = Label("@nodejs//:node"),
    ),
    "_tsc": attr.label(
      executable = True,
      cfg="host",
      default = Label("@build_bazel_rules_nodejs//internal/rollup:tsc"),
    ),
    "_yarn": attr.label(
      executable = True,
      cfg = "host",
      default = Label("@yarn//:yarn"),
    ),
    "_internal_packages": attr.label(
      default = Label("//internal:packages"),
    ),
    "_ts_library_create_full_src_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/ts_library:create_full_src.js"),
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
  npm_packages = (
    npm_packages_list[0] if len(npm_packages_list) == 1
    else ctx.attr._empty_npm_packages
  )
  runfiles = ctx.runfiles(
    files = [
      ctx.executable._yarn,
      npm_packages[NpmPackagesInfo].installed_dir,
      ctx.outputs.full_src_dir,
    ],
  )
  ctx.actions.run(
    inputs = [
      ctx.executable._yarn,
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
    executable = ctx.executable._node,
    env = {
      "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + '/node_modules',
    },
    arguments = [
      ctx.file._ts_script_compile_script.path,
      ctx.executable._yarn.path,
      ctx.executable._yarn.short_path,
      ctx.attr.cmd,
      npm_packages[NpmPackagesInfo].installed_dir.path,
      npm_packages[NpmPackagesInfo].installed_dir.short_path,
      ctx.build_file_path,
      ("|".join([f.path for f in ctx.files.srcs])),
      ("|".join([
        d.label.package + ':' +
        d.label.name + ':' +
        d[TsLibraryInfo].compiled_dir.path
        for d in internal_deps
      ])),
      ctx.outputs.full_src_dir.path,
      ctx.outputs.full_src_dir.short_path,
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
    "_node": attr.label(
      allow_files = True,
      executable = True,
      cfg = "host",
      default = Label("@nodejs//:node"),
    ),
    "_yarn": attr.label(
      executable = True,
      cfg = "host",
      default = Label("@yarn//:yarn"),
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

def _ts_binary_compile(ctx):
  ctx.actions.run(
    inputs = [
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.attr._webpack_npm_packages[NpmPackagesInfo].installed_dir,
      ctx.attr.lib[TsLibraryInfo].npm_packages_installed_dir,
      ctx.attr.lib[TsLibraryInfo].full_src_dir,
    ] + ctx.files._ts_binary_compile_script,
    outputs = [ctx.outputs.executable_file],
    executable = ctx.executable._node,
    env = {
      "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + '/node_modules',
    },
    arguments = [
      ctx.file._ts_binary_compile_script.path,
      ctx.build_file_path,
      ctx.attr.entry,
      ctx.attr._webpack_npm_packages[NpmPackagesInfo].installed_dir.path,
      ctx.attr.lib[TsLibraryInfo].npm_packages_installed_dir.path,
      ctx.attr.lib[TsLibraryInfo].full_src_dir.path,
      ctx.outputs.executable_file.path,
    ],
  )

def _ts_binary_impl(ctx):
  _ts_binary_compile(ctx)
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
    "_node": attr.label(
      allow_files = True,
      executable = True,
      cfg = "host",
      default = Label("@nodejs//:node"),
    ),
    "_tsc": attr.label(
      executable = True,
      cfg="host",
      default = Label("@build_bazel_rules_nodejs//internal/rollup:tsc"),
    ),
    "_yarn": attr.label(
      executable = True,
      cfg = "host",
      default = Label("@yarn//:yarn"),
    ),
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
  ctx.actions.run(
      inputs = [
        ctx.file._npm_packages_install,
        ctx.executable._yarn,
        ctx.file.package_json,
        ctx.file.yarn_lock,
      ],
      outputs = [ctx.outputs.installed_dir],
      executable = ctx.executable._node,
      arguments = [
        ctx.file._npm_packages_install.path,
        ctx.executable._yarn.path,
        ctx.file.package_json.path,
        ctx.file.yarn_lock.path,
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
    "_node": attr.label(
      allow_files = True,
      executable = True,
      cfg = "host",
      default = Label("@nodejs//:node"),
    ),
    "_yarn": attr.label(
      executable = True,
      cfg = "host",
      default = Label("@yarn//:yarn"),
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
