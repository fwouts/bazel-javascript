load("//internal/js_library:rule.bzl", "JsLibraryInfo")
load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

def _js_script_impl(ctx):
  # Create a directory that contains:
  # - source code from the js_library we depend on
  # - package.json with {
  #     "scripts": {
  #       "start": "[cmd]"
  #     }
  #   }
  #
  # Note that node_modules/ will not contain external dependencies from NPM.
  # Instead, the NODE_PATH will point to the node_modules/ directory of
  # the npm_packages target we depend on. This means we don't have to lose
  # performance by copy-pasting node_modules with hundreds of packages.
  #
  # Also generate a shell script that will run `yarn start`.
  ctx.actions.run_shell(
    inputs = [
      ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
      ctx.attr.lib[JsLibraryInfo].full_src_dir,
      ctx.file._js_script_compile_script,
    ],
    outputs = [
      ctx.outputs.compiled_dir,
      ctx.outputs.executable_file,
    ],
    command = "NODE_PATH=" + ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules node \"$@\"",
    use_default_shell_env = True,
    arguments = [
      # Run `node js_script/compile.js`.
      ctx.file._js_script_compile_script.path,
      # The command to run.
      ctx.attr.cmd,
      # Directory containing node_modules/ with all external NPM packages
      # installed.
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.path,
      # Same path required in short form for the shell script.
      ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.short_path,
      # Compiled directory of the js_library we depend on.
      ctx.attr.lib[JsLibraryInfo].full_src_dir.path,
      # Directory in which to create package.json and copy sources.
      ctx.outputs.compiled_dir.path,
      # Same path required in short form for the shell script.
      ctx.outputs.compiled_dir.short_path,
      # Path to generate the shell script.
      ctx.outputs.executable_file.path,
    ],
  )
  return [
    DefaultInfo(
      executable = ctx.outputs.executable_file,
      runfiles = ctx.runfiles(
        files = [
          ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
          ctx.outputs.compiled_dir,
        ],
      ),
    ),
  ]

js_script = rule(
  implementation = _js_script_impl,
  attrs = {
    "cmd": attr.string(),
    "lib": attr.label(
      providers = [JsLibraryInfo],
    ),
    "_internal_packages": attr.label(
      default = Label("//internal:packages"),
    ),
    "_js_script_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/js_script_and_test:compile.js"),
    ),
  },
  executable = True,
  outputs = {
    "compiled_dir": "%{name}_compiled_dir",
    "executable_file": "%{name}.sh",
  },
)

# js_test is identical to js_script, but it's marked as "test" instead of
# "executable".
js_test = rule(
  implementation = _js_script_impl,
  attrs = {
    "cmd": attr.string(),
    "lib": attr.label(
      providers = [JsLibraryInfo],
    ),
    "_internal_packages": attr.label(
      default = Label("//internal:packages"),
    ),
    "_js_script_compile_script": attr.label(
      allow_files = True,
      single_file = True,
      default = Label("//internal/js_script_and_test:compile.js"),
    ),
  },
  test = True,
  outputs = {
    "compiled_dir": "%{name}_compiled_dir",
    "executable_file": "%{name}.sh",
  },
)
