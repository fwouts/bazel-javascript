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
  attrs={
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
