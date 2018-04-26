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

def _npm_package_impl(ctx):
  ctx.actions.run(
    arguments = [
      "--cwd",
      ctx.genfiles_dir.path,
      "--modules-folder",
      ctx.outputs.node_modules.path,
      "add",
      ctx.attr.package + "@" + ctx.attr.version,
    ],
    outputs = [ctx.outputs.node_modules],
    executable = ctx.executable._yarn,
  )

npm_package = rule (
  implementation = _npm_package_impl,
  attrs = {
    "package": attr.string(),
    "version": attr.string(),
    "_yarn": attr.label(
      executable = True,
      cfg="host",
      default = Label("@yarn//:yarn"),
    ),
  },
  outputs = {
    "node_modules": "%{name}_node_modules",
  },
)
