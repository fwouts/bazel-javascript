TsLibraryInfo = provider(fields=["compiled_dir", "full_src_dir", "srcs"])

def _ts_library_impl(ctx):
  ctx.actions.run(
    inputs = [
      d[TsLibraryInfo].compiled_dir
      for d in ctx.attr.deps
    ] + ctx.files.srcs + ctx.files._ts_library_generate_full_src_script,
    outputs = [
      ctx.outputs.full_src_dir,
    ],
    executable = ctx.executable._node,
    arguments = [
      f.path for f in ctx.files._ts_library_generate_full_src_script
    ] + [
      ctx.build_file_path,
      ctx.outputs.full_src_dir.path,
    ] + [
      d.label.package + ':' +
      d.label.name + ':' +
      ("|".join(d[TsLibraryInfo].srcs)) + ":" +
      d[TsLibraryInfo].compiled_dir.path
      for d in ctx.attr.deps
    ] + [
      f.path for f in ctx.files.srcs
    ],
  )
  ctx.actions.run(
    inputs = [ctx.outputs.full_src_dir],
    outputs = [ctx.outputs.compiled_dir],
    executable = ctx.executable._tsc,
    arguments = [
      "--declaration",
      "-p",
      ctx.outputs.full_src_dir.path,
      "--outDir",
      ctx.outputs.compiled_dir.path,
    ],
  )
  return [
    TsLibraryInfo(
      srcs = [f.path for f in ctx.files.srcs],
      compiled_dir = ctx.outputs.compiled_dir,
      full_src_dir = ctx.outputs.full_src_dir,
    ),
  ]

ts_library = rule(
  implementation=_ts_library_impl,
  attrs = {
    "srcs": attr.label_list(
      allow_files=[".ts"],
    ),
    "deps": attr.label_list(
      providers = [TsLibraryInfo],
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
    "_ts_library_generate_full_src_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//:ts_library_generate_full_src.js"),
    ),
  },
  outputs = {
    "compiled_dir": "%{name}_compiled",
    "full_src_dir": "%{name}_full_src",
  },
)

def _ts_binary_impl(ctx):
  compiled_file = ctx.actions.declare_file(ctx.label.name + "_compiled_file")
  ctx.actions.run(
    inputs = [ctx.attr.lib[TsLibraryInfo].full_src_dir],
    outputs = [compiled_file],
    executable = ctx.executable._tsc,
    arguments = [
      "-p",
      ctx.attr.lib[TsLibraryInfo].full_src_dir.path,
      "--outFile",
      compiled_file.path,
      "--module",
      "amd",
      "--moduleResolution",
      "node",
    ],
  )
  ctx.actions.run_shell(
    inputs = [compiled_file],
    outputs = [ctx.outputs.executable_file],
    command = "echo \"#!/usr/bin/env node\" > %s && cat %s >> %s" % (
      ctx.outputs.executable_file.path,
      compiled_file.path,
      ctx.outputs.executable_file.path,
    ),
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
    "_tsc": attr.label(
      executable = True,
      cfg="host",
      default = Label("@build_bazel_rules_nodejs//internal/rollup:tsc"),
    ),
  },
  executable = True,
  outputs = {
    "executable_file": "%{name}.js",
  },
)

NpmPackageInfo = provider(fields=["dir", "modules_path"])

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
