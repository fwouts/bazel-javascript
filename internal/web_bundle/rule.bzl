load("//internal/js_library:rule.bzl", "JsLibraryInfo")
load("//internal/js_module:rule.bzl", "JsModuleInfo")
load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

def _web_bundle_impl(ctx):
  webpack_config = _create_webpack_config(ctx)

  # Compile using the Webpack config.
  ctx.actions.run(
    inputs = [
      ctx.file._web_bundle_compile_script,
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
      ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir,
      webpack_config,
    ] + [
      module[JsLibraryInfo].compiled_javascript_dir
      for module in ctx.attr.modules
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
      # Modules to expose to Webpack through aliases.
      ("|".join([
        module[JsModuleInfo].name + ":" + module[JsLibraryInfo].compiled_javascript_dir.path + '/' + _strip_buildfile(module[JsLibraryInfo].build_file_path) + ('/' + module[JsModuleInfo].single_file if module[JsModuleInfo].single_file else '') for module in ctx.attr.modules
      ])),
      # Environment variables to set in compiled JavaScript.
      ("|".join([
        key + ":" + value for key, value in ctx.attr.env.items()
      ])),
      # Directory in which to place the compiled JavaScript.
      ctx.outputs.bundle_dir.path,
      # Path of the webpack config file.
      webpack_config.path,
    ],
  )

def _web_bundle_dev_server_impl(ctx):
  webpack_config = _create_webpack_config(ctx)

  # Serve using Webpack development server.
  webpack_devserver_js = ctx.actions.declare_file(ctx.label.name + ".serve.js")
  ctx.actions.write(
    output = webpack_devserver_js,
    content = """
const fs = require("fs-extra");
const path = require("path");
const chokidar = require("chokidar");

// We cannot build directly from the source directory as Webpack struggles to
// watch it correctly. Instead, we watch the source directory ourselves with
// chokidar (below), and copy it whenever it changes.
const bazelSrcDir = "{source_dir}";
const srcDir = "devserver-src";
const aliases = {{{aliases}}};
const env = {{{env}}};

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
  if (!fs.existsSync(bazelSrcDir)) {{
    // Try again later.
    console.warn("Source directory is gone, trying again soon...");
    copySrcSoon();
    return;
  }}
  try {{
    fs.copySync(bazelSrcDir, srcDir, {{
      dereference: true,
      overwrite: true,
    }});
    console.log("Source directory updated successfully.")
  }} catch (e) {{
    console.warn("Error copying, trying again soon...");
    copySrcSoon();
  }}
}}

chokidar.watch(bazelSrcDir, {{
  ignoreInitial: true,
  followSymlinks: true,
}}).on("all", copySrcSoon);
copySrc();

const configGenerator = require(path.resolve("{webpack_config}"));
const config = configGenerator(
  srcDir,
  aliases,
  env,
  "{output_bundle_dir}",
  path.resolve("{dependencies_packages_dir}"),
  "{internal_packages_dir}",
  "{html_template}",
);

if (config.mode === "production") {{
  console.error("Development server is not available when mode is 'production'.");
  process.exit(1);
}}

const webpack = require('webpack');
const WebpackDevServer = require('webpack-dev-server');
const port = 8080;

var options = require(path.resolve("{dev_server_options}"));
options.publicPath = config.output.publicPath;

const server = new WebpackDevServer(webpack(config), options);

server.listen(port, 'localhost', function (err) {{
  if (err) {{
    console.log(err);
  }} else {{
    console.log('WebpackDevServer listening at localhost:', port);
  }}
}});



""".format(
      webpack_config = webpack_config.short_path,
      # Directory containing the compiled source code of the js_library.
      source_dir = ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir.short_path,
      # Modules to expose to Webpack through aliases.
      aliases = (",".join([
        "'" + module[JsModuleInfo].name + "': path.resolve('" + module[JsLibraryInfo].compiled_javascript_dir.short_path + '/' + _strip_buildfile(module[JsLibraryInfo].build_file_path) + ('/' + module[JsModuleInfo].single_file if module[JsModuleInfo].single_file else '') + "')" for module in ctx.attr.modules
      ])),
      # Environment variables to set in compiled JavaScript.
      env = (",".join([
        "'" + key + "': JSON.stringify('" + value + "')" for key, value in ctx.attr.env.items()
      ])),
      # Unused output bundle directory.
      output_bundle_dir = "",
      # Directory containing external NPM dependencies the code depends on.
      dependencies_packages_dir = ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.short_path,
      # Directory containing internal NPM dependencies (for build tools).
      internal_packages_dir = ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.short_path,
      # Template index.html for Webpack.
      html_template = ctx.file.html_template.short_path if ctx.file.html_template else "",
      dev_server_options = ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir.short_path + "/" + ctx.file.dev_server_options.short_path,
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
        ] + [
          module[JsLibraryInfo].compiled_javascript_dir
          for module in ctx.attr.modules
        ] + ctx.files.html_template
      ),
    ),
  ]

def _strip_buildfile(path):
  if path.endswith('/BUILD.bazel'):
    return path[:-12]
  elif path.endswith('/BUILD'):
    return path[:-6]
  else:
    return path

def _create_webpack_config(ctx):
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

  return webpack_config

# Shared attributes between bundle and devserver rules.
_ATTRS = {
    "lib": attr.label(
      providers = [JsLibraryInfo],
      mandatory = True,
    ),
    "modules": attr.label_list(
      providers = [JsModuleInfo],
    ),
    "env": attr.string_dict(),
    "entry": attr.string(
      mandatory = True,
    ),
    "output": attr.string(
      default = "bundle.js",
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
    "dev_server_options": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/web_bundle:dev_server_options.js"),
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
  }

_web_bundle = rule(
  implementation=_web_bundle_impl,
  attrs = _ATTRS,
  outputs = {
    "bundle_dir": "%{name}_bundle",
  },
)

_web_bundle_dev_server = rule(
  implementation=_web_bundle_dev_server_impl,
  attrs = _ATTRS,
  outputs = {
    "devserver": "%{name}_devserver",
  },
  executable = True,
)

def web_bundle(name, tags = [], **kwargs):
  _web_bundle(
    name = name,
    tags = tags,
    **kwargs
  )
  _web_bundle_dev_server(
    name = name + "_server",
    tags = tags + [
      "ibazel_notify_changes",
      "ibazel_live_reload",
    ],
    **kwargs
  )
