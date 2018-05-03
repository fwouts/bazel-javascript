load("//internal/js_library:rule.bzl", "JsLibraryInfo")
load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

def _js_binary_impl(ctx):
  ctx.actions.run_shell(
    inputs = [
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
      ctx.attr.lib[JsLibraryInfo].full_src_dir,
    ] + ctx.files._js_binary_compile_script,
    outputs = [
      ctx.outputs.executable_file,
    ],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node js_binary/compile.js`.
      ctx.file._js_binary_compile_script.path,
      # Entry point for Webpack (e.g. "main.ts").
      ctx.attr.entry,
      # Directory containing external NPM dependencies the code depends on.
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.path,
      # Directory containing the compiled source code of the js_library.
      ctx.attr.lib[JsLibraryInfo].full_src_dir.path,
      # Directory in which to place the compiled JavaScript.
      ctx.outputs.executable_file.path,
    ],
  )
  return [
    DefaultInfo(
      executable = ctx.outputs.executable_file,
    ),
  ]

js_binary = rule(
  implementation=_js_binary_impl,
  attrs = {
    "lib": attr.label(
      providers = [JsLibraryInfo],
    ),
    "entry": attr.string(),
    "_internal_packages": attr.label(
      default = Label("//internal:packages"),
    ),
    "_js_binary_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/js_binary:compile.js"),
    ),
  },
  executable = True,
  outputs = {
    "executable_file": "%{name}.js",
  },
)
