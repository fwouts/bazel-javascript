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
      # Target for Webpack.
      ctx.attr.target,
      # Mode for Webpack.
      ctx.attr.mode,
      # Library for Webpack (optional).
      ctx.attr.library_name + "/" + ctx.attr.library_target if ctx.attr.library_name else "",
      # Enable split chunks or not.
      "1" if ctx.attr.split_chunks else "0",
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
      # Template index.html for Webpack.
      ctx.file.html_template.path,
      # Directory containing internal NPM dependencies (for build tools).
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path,
      # Directory containing external NPM dependencies the code depends on.
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.path,
      # Directory containing the compiled source code of the js_library.
      ctx.attr.lib[JsLibraryInfo].full_src_dir.path,
      # Directory in which to place the compiled JavaScript.
      ctx.outputs.bundle_dir.path,
      # Path of the webpack config file.
      webpack_config.path,
    ],
  )

  # Serve using Webpack development server.
  webpack_devserver_js = ctx.actions.declare_file(ctx.label.name + ".serve.js")
  ctx.actions.write(
    output = webpack_devserver_js,
    content = """
const fs = require("fs-extra");
const path = require("path");
const serve = require("webpack-serve");

const configGenerator = require(path.resolve("{webpack_config}"));
const config = configGenerator(
  "{source_dir}",
  "{output_bundle_dir}",
  "{dependencies_packages_dir}",
  "{internal_packages_dir}",
  "{html_template}",
);

serve({{
  config,
}}).then(server => {{
  server.on("build-started", ({{ compiler }}) => {{
    compiler.hooks.watchRun.tapPromise("check-entry-exists", async () => {{
      while (!fs.existsSync(config.entry[0])) {{
        console.log("Waiting for config.entry[0] to be compiled...");
        await new Promise(resolve => setTimeout(resolve, 1000));
      }}
    }})
  }});
}});
""".format(
      webpack_config = webpack_config.short_path,
      # Directory containing the compiled source code of the js_library.
      source_dir = ctx.attr.lib[JsLibraryInfo].full_src_dir.short_path,
      # Directory in which to place the compiled JavaScript.
      output_bundle_dir = ctx.outputs.bundle_dir.path,
      # Directory containing external NPM dependencies the code depends on.
      dependencies_packages_dir = ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.short_path,
      # Directory containing internal NPM dependencies (for build tools).
      internal_packages_dir = ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.short_path,
      # Template index.html for Webpack.
      html_template = ctx.file.html_template.short_path,
    ),
  )
  ctx.actions.write(
    output = ctx.outputs.devserver,
    is_executable = True,
    content = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.short_path + "/node_modules node " + webpack_devserver_js.short_path,
  )

  return [
    DefaultInfo(
      executable = ctx.outputs.devserver,
      runfiles = ctx.runfiles(
        files = [
          ctx.file._web_bundle_compile_script,
          webpack_devserver_js,
          ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
          ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
          ctx.attr.lib[JsLibraryInfo].full_src_dir,
          ctx.file.html_template,
          webpack_config,
        ],
      ),
    ),
  ]

web_bundle_internal = rule(
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
    "devserver": "%{name}_devserver",
  },
  executable = True,
)

def web_bundle(tags = [], **kwargs):
  web_bundle_internal(
    tags = tags + [
      "ibazel_notify_changes",
      "ibazel_live_reload",
    ],
    **kwargs
  )
