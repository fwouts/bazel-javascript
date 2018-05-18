load("//internal/js_library:rule.bzl", "JsLibraryInfo")
load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

def _web_bundle_impl(ctx):
  webpack_config = ctx.actions.declare_file(ctx.label.name + ".webpack.config.js")

  # Create the Webpack config file.
  ctx.actions.run_shell(
    inputs = [
      ctx.file._web_bundle_create_webpack_config_script,
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
      ctx.attr.lib[JsLibraryInfo].full_src_dir,
      ctx.file.html_template,
    ],
    outputs = [
      webpack_config,
    ],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node web_bundle/create_webpack_config.js`.
      ctx.file._web_bundle_create_webpack_config_script.path,
      # Path of the directory containing the lib's BUILD file.
      ctx.attr.lib[JsLibraryInfo].build_file_path,
      # Entry point for Webpack (e.g. "main.ts").
      ctx.attr.entry,
      # Template index.html for Webpack.
      ctx.file.html_template.path,
      # Target for Webpack.
      ctx.attr.target,
      # Mode for Webpack.
      ctx.attr.mode,
      # Library for Webpack (optional).
      ctx.attr.library_name + "/" + ctx.attr.library_target if ctx.attr.library_name else "",
      # Enable split chunks or not.
      "1" if ctx.attr.split_chunks else "0",
      # Directory containing internal NPM dependencies (for build tools).
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path,
      # Directory containing external NPM dependencies the code depends on.
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.path,
      # Directory containing the compiled source code of the js_library.
      ctx.attr.lib[JsLibraryInfo].full_src_dir.path,
      # Directory in which to place the compiled JavaScript.
      ctx.outputs.bundle_dir.path,
      # Path where to create the Webpack config.
      webpack_config.path,
    ],
  )

  # Compile using the Webpack config.
  ctx.actions.run_shell(
    inputs = [
      ctx.file._web_bundle_compile_script,
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
      ctx.attr.lib[JsLibraryInfo].full_src_dir,
      ctx.file.html_template,
      webpack_config,
    ],
    outputs = [
      ctx.outputs.bundle_dir,
    ],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node web_bundle/compile.js`.
      ctx.file._web_bundle_compile_script.path,
      # Path of the webpack config file.
      webpack_config.path,
    ],
  )

web_bundle = rule(
  implementation=_web_bundle_impl,
  attrs = {
    "lib": attr.label(
      providers = [JsLibraryInfo],
    ),
    "entry": attr.string(),
    "target": attr.string(
      values = [
        "async-node",
        "node",
        "electron-main",
        "electron-renderer",
        "node",
        "node-webkit",
        "web",
        "webworker",
      ],
    ),
    "mode": attr.string(
      values = [
        "none",
        "development",
        "production",
      ],
      default = "none",
    ),
    "split_chunks": attr.bool(
      default = False,
    ),
    "html_template": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/web_bundle:default.index.html"),
    ),
    "library_name": attr.string(),
    "library_target": attr.string(
      values = [
        "var",
        "assign",
        "this",
        "window",
        "global",
        "commonjs",
        "commonjs2",
        "amd",
        "umd",
        "jsonp",
      ],
      default = "umd",
    ),
    "_internal_packages": attr.label(
      default = Label("//internal:packages"),
    ),
    "_web_bundle_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/web_bundle:compile.js"),
    ),
    "_web_bundle_create_webpack_config_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/web_bundle:create_webpack_config.js"),
    ),
  },
  outputs = {
    "bundle_dir": "%{name}_bundle",
  },
)
