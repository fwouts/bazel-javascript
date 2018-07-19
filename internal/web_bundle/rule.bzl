load("//internal/js_library:rule.bzl", "JsLibraryInfo")
load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

def _web_bundle_impl(ctx):
  webpack_config = ctx.actions.declare_file(ctx.label.name + ".webpack.config.js")

  # Create the Webpack config file.
  ctx.actions.run(
    inputs = [
      ctx.file._web_bundle_create_webpack_config_script,
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
      ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir,
    ],
    outputs = [
      webpack_config,
    ],
    executable = ctx.file._internal_nodejs,
    env = {
      "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules"
    },
    arguments = [
      # Run `node web_bundle/create_webpack_config.js`.
      ctx.file._web_bundle_create_webpack_config_script.path,
      # Path of the directory containing the lib's BUILD.bazel file.
      ctx.attr.lib[JsLibraryInfo].build_file_path,
      # Entry point for Webpack (e.g. "main.ts").
      ctx.attr.entry,
      # Output file name (e.g. "bundle.js").
      ctx.attr.output,
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
  ctx.actions.run(
    inputs = [
      ctx.file._web_bundle_compile_script,
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
      ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir,
      webpack_config,
    ] + ctx.files.html_template,
    outputs = [
      ctx.outputs.bundle_dir,
    ],
    executable = ctx.file._internal_nodejs,
    env = {
      "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules"
    },
    arguments = [
      # Run `node web_bundle/compile.js`.
      ctx.file._web_bundle_compile_script.path,
      # Template index.html for Webpack.
      ctx.file.html_template.path if ctx.file.html_template else "",
      # Directory containing internal NPM dependencies (for build tools).
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path,
      # Directory containing external NPM dependencies the code depends on.
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.path,
      # Directory containing the compiled source code of the js_library.
      ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir.path,
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
const chokidar = require("chokidar");

// We cannot build directly from the source directory as Webpack struggles to
// watch it correctly. Instead, we watch the source directory ourselves with
// chokidar (below), and copy it whenever it changes.
const bazelSrcDir = "{source_dir}";
const srcDir = "devserver-src";

// copySrcSoon() will ensures that copySrc() is only called at most once per
// second.
let copySoonTimeout = null;
function copySrcSoon() {{
  if (copySoonTimeout) {{
    clearTimeout(copySoonTimeout);
  }}
  copySoonTimeout = setTimeout(copySrc, 1000);
}}

// copySrc() copies files from Bazel's source to our source, which will be
// picked up by Webpack.
function copySrc() {{
  fs.copySync(bazelSrcDir, srcDir, {{
    dereference: true,
    overwrite: true,
  }});
}}

// Note: path.dirname() is essential here. Watching the directory directly
// does not work, probably because of the symlinks that Bazel shuffles around.
chokidar.watch(path.dirname(bazelSrcDir), {{
  ignoreInitial: true,
  followSymlinks: true,
}}).on("all", copySrcSoon);
copySrc();

const configGenerator = require(path.resolve("{webpack_config}"));
const config = configGenerator(
  srcDir,
  "{output_bundle_dir}",
  path.resolve("{dependencies_packages_dir}"),
  "{internal_packages_dir}",
  "{html_template}",
);

if (config.mode === "production") {{
  console.error("Development server is not available when mode is 'production'.");
  process.exit(1);
}}

serve({{
  config,
  hot: true,
}});
""".format(
      webpack_config = webpack_config.short_path,
      # Directory containing the compiled source code of the js_library.
      source_dir = ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir.short_path,
      # Directory in which to place the compiled JavaScript.
      output_bundle_dir = ctx.outputs.bundle_dir.short_path,
      # Directory containing external NPM dependencies the code depends on.
      dependencies_packages_dir = ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.short_path,
      # Directory containing internal NPM dependencies (for build tools).
      internal_packages_dir = ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.short_path,
      # Template index.html for Webpack.
      html_template = ctx.file.html_template.short_path if ctx.file.html_template else "",
    ),
  )
  ctx.actions.write(
    output = ctx.outputs.devserver,
    is_executable = True,
    content = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.short_path + "/node_modules " + ctx.file._internal_nodejs.path + " " + webpack_devserver_js.short_path,
  )

  return [
    DefaultInfo(
      executable = ctx.outputs.devserver,
      runfiles = ctx.runfiles(
        files = [
          ctx.file._internal_nodejs,
          ctx.file._web_bundle_compile_script,
          webpack_devserver_js,
          ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
          ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
          ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir,
          webpack_config,
        ] + ctx.files.html_template
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
    "output": attr.string(
      default = "bundle.js",
    ),
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
    "_internal_nodejs": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("@nodejs//:node"),
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
