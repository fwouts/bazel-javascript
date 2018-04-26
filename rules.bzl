def _ts_library_impl(ctx):
  ctx.actions.run(
    inputs = ctx.files.srcs,
    outputs = [ctx.outputs.compiled_file],
    arguments = [f.path for f in ctx.files.srcs] + [
      "--outFile",
      ctx.outputs.compiled_file.path,
    ],
    executable = ctx.executable._tsc,
  )

ts_library = rule(
  implementation=_ts_library_impl,
  attrs = {
    "srcs": attr.label_list(
      allow_files=[".ts"],
    ),
    "_tsc": attr.label(
      executable = True,
      cfg="host",
      default = Label("@build_bazel_rules_nodejs//internal/rollup:tsc"),
    ),
  },
  outputs = {
    "compiled_file": "%{name}.js",
  },
)

def _ts_binary_impl(ctx):
  ctx.actions.run_shell(
    inputs = [ctx.file.lib],
    outputs = [ctx.outputs.executable_file],
    command = "echo \"#!/usr/bin/env node\" > %s && cat %s >> %s" % (
      ctx.outputs.executable_file.path,
      ctx.file.lib.path,
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
      single_file = True,
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
