TsLibraryInfo = provider(fields=[
  "installed_external_deps_dir",
  "compiled_dir",
  "full_src_dir",
  "srcs",
  "external_deps",
  "internal_deps",
])
NpmPackageInfo = provider(fields=[
  "package",
  "version",
  "dir",
  "modules_path",
])

def _download_external_deps(ctx, external_deps, destination):
  ctx.actions.run(
    inputs = [ctx.executable._yarn] + ctx.files._download_external_deps_script,
    outputs = [destination],
    executable = ctx.executable._node,
    arguments = [
      f.path for f in ctx.files._download_external_deps_script
    ] + [
      ctx.executable._yarn.path,
      ("|".join([
        d.package + "@" + d.version
        for d in external_deps
      ])),
      destination.path,
    ],
  )

def _ts_library_create_full_src(ctx, external_deps, internal_deps):
  ctx.actions.run(
    inputs = [
      ctx.executable._yarn,
      ctx.outputs.installed_external_deps_dir,
    ] + [
      d[TsLibraryInfo].compiled_dir
      for d in internal_deps
    ] + ctx.files.srcs + ctx.files._ts_library_create_full_src_script,
    outputs = [ctx.outputs.full_src_dir],
    executable = ctx.executable._node,
    arguments = [
      f.path for f in ctx.files._ts_library_create_full_src_script
    ] + [
      ctx.executable._yarn.path,
      ctx.outputs.installed_external_deps_dir.path,
      ctx.build_file_path,
      ("|".join([
        d.package + "@" + d.version
        for d in external_deps
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

def _ts_library_compile(ctx):
  ctx.actions.run(
    inputs = [ctx.outputs.full_src_dir],
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
  # Steps:
  # 1. Create an empty directory with all external deps installed.
  # 2. Create a directory with srcs + (external + internal) deps in node_modules.
  # 3. Compile directory to produce corresponding .js and .d.ts files.
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
  external_deps = depset(
    direct = [
      dep[NpmPackageInfo]
      for dep in ctx.attr.deps
      if NpmPackageInfo in dep
    ],
    transitive = [
      dep[TsLibraryInfo].external_deps
      for dep in ctx.attr.deps
      if TsLibraryInfo in dep
    ],
  )
  _download_external_deps(
    ctx,
    external_deps,
    ctx.outputs.installed_external_deps_dir,
  )
  _ts_library_create_full_src(
    ctx,
    external_deps,
    internal_deps,
  )
  _ts_library_compile(ctx)
  return [
    TsLibraryInfo(
      srcs = [f.path for f in ctx.files.srcs],
      installed_external_deps_dir = ctx.outputs.installed_external_deps_dir,
      compiled_dir = ctx.outputs.compiled_dir,
      full_src_dir = ctx.outputs.full_src_dir,
      external_deps = external_deps,
      internal_deps = internal_deps,
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
        [NpmPackageInfo],
      ],
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
    "_download_external_deps_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//ts_common:download_external_deps.js"),
    ),
    "_ts_library_create_full_src_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//ts_library:create_full_src.js"),
    ),
  },
  outputs = {
    "installed_external_deps_dir": "%{name}_external_deps",
    "compiled_dir": "%{name}_compiled",
    "full_src_dir": "%{name}_full_src",
  },
)

def _ts_script_impl(ctx):
  # 1. Create an empty directory with all external deps installed.
  # 2. Create a directory with srcs + (external + internal) deps in node_modules.
  # 3. Run script in directory.
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
  external_deps = depset(
    direct = [
      dep[NpmPackageInfo]
      for dep in ctx.attr.deps
      if NpmPackageInfo in dep
    ],
    transitive = [
      dep[TsLibraryInfo].external_deps
      for dep in ctx.attr.deps
      if TsLibraryInfo in dep
    ],
  )
  build_dir = ctx.actions.declare_directory(ctx.label.name + "_build_dir")
  runfiles = ctx.runfiles(
    files = [
      ctx.executable._yarn,
      build_dir,
    ],
  )
  ctx.actions.run(
    inputs = [
      ctx.executable._yarn,
    ] + ctx.files.srcs + ctx.files._ts_script_compile_script + [
      d[TsLibraryInfo].compiled_dir
      for d in internal_deps
    ],
    outputs = [build_dir, ctx.outputs.executable_file],
    executable = ctx.executable._node,
    arguments = [
      f.path for f in ctx.files._ts_script_compile_script
    ] + [
      ctx.executable._yarn.path,
      ctx.executable._yarn.short_path,
      ctx.attr.cmd,
      ctx.build_file_path,
      ("|".join([f.path for f in ctx.files.srcs])),
      ("|".join([
        d.package + "@" + d.version
        for d in external_deps
      ])),
      ("|".join([
        d.label.package + ':' +
        d.label.name + ':' +
        d[TsLibraryInfo].compiled_dir.path
        for d in internal_deps
      ])),
      build_dir.path,
      build_dir.short_path,
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
        [NpmPackageInfo],
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
    "_ts_script_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//:ts_script_compile.js"),
    ),
  },
  executable = True,
  outputs = {
    "executable_file": "%{name}.sh",
  },
)

def _ts_binary_impl(ctx):
  # Steps:
  # 1. Set up webpack and other build dependencies in empty directory.
  # 2. Copy ts_library directory into a new directory + add webpack and co.
  # 3. Compile with webpack.
  build_dir = ctx.actions.declare_directory(ctx.label.name + "_build_dir")
  ctx.actions.run(
    inputs = [
      ctx.executable._yarn,
      ctx.attr.lib[TsLibraryInfo].full_src_dir,
    ] + ctx.files._ts_binary_compile_script,
    outputs = [build_dir, ctx.outputs.executable_file],
    executable = ctx.executable._node,
    arguments = [
      f.path for f in ctx.files._ts_binary_compile_script
    ] + [
      ctx.executable._yarn.path,
      ctx.attr.entry,
      ctx.attr.lib[TsLibraryInfo].full_src_dir.path,
      ("|".join([
        p.package + "@" + p.version
        for p in ctx.attr.lib[TsLibraryInfo].external_deps
      ])),
      build_dir.path,
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
    "_ts_binary_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//:ts_binary_compile.js"),
    ),
  },
  executable = True,
  outputs = {
    "executable_file": "%{name}.js",
  },
)

def _npm_package_impl(ctx):
  ctx.actions.run(
    executable = ctx.executable._yarn,
    outputs = [ctx.outputs.dir],
    arguments = [
      "--cwd",
      ctx.outputs.dir.path,
      "add",
      ctx.attr.package + "@" + ctx.attr.version,
    ],
  )
  return [
    NpmPackageInfo(
      package = ctx.attr.package,
      version = ctx.attr.version,
      dir = ctx.outputs.dir,
      modules_path = ctx.outputs.dir.short_path + '/node_modules'
    ),
  ]

npm_package = rule(
  implementation = _npm_package_impl,
  attrs = {
    "package": attr.string(),
    "version": attr.string(),
    "_yarn": attr.label(
      executable = True,
      cfg = "host",
      default = Label("@yarn//:yarn"),
    ),
  },
  outputs = {
    "dir": "%{name}_dir",
  },
)

def _npm_binary_impl(ctx):
  modules_path = ctx.attr.package[NpmPackageInfo].modules_path
  ctx.actions.write(
    output = ctx.outputs.bin,
    content = "%s/.bin/%s" % (modules_path, ctx.attr.binary),
    is_executable = True,
  )
  return [
    DefaultInfo(
      runfiles = ctx.runfiles(
        files = [ctx.attr.package[NpmPackageInfo].dir],
      ),
      executable = ctx.outputs.bin,
    )
  ]

npm_binary = rule(
  implementation = _npm_binary_impl,
  attrs = {
    "package": attr.label(),
    "binary": attr.string(),
  },
  outputs = {
    "bin": "%{name}.sh"
  },
  executable = True,
)
