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
    ctx.actions.run(
        inputs = [
            ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
            ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
            ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir,
            ctx.file._js_script_compile_script,
        ],
        outputs = [
            ctx.outputs.compiled_dir,
            ctx.outputs.executable_file,
        ],
        executable = ctx.file._internal_nodejs,
        env = {
            "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules",
            "GENDIR": ctx.var["GENDIR"],
        },
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
            ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir.path,
            # Directory in which to create package.json and copy sources.
            ctx.outputs.compiled_dir.path,
            # Same path required in short form for the shell script.
            ctx.outputs.compiled_dir.short_path,
            # BUILD.bazel file path for the js_library.
            ctx.attr.lib[JsLibraryInfo].build_file_path,
            # Path to generate the shell script.
            ctx.outputs.executable_file.path,
            # Path to yarn
            ctx.file._internal_yarn.path,
        ],
    )
    return [
        DefaultInfo(
            executable = ctx.outputs.executable_file,
            runfiles = ctx.runfiles(
                files = [
                    ctx.file._internal_yarn,
                    ctx.file._internal_nodejs,
                    ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
                    ctx.outputs.compiled_dir,
                ],
            ),
        ),
    ]

js_script = rule(
    attrs = {
        "cmd": attr.string(),
        "lib": attr.label(
            providers = [JsLibraryInfo],
        ),
        "_internal_nodejs": attr.label(
            allow_single_file = True,
            default = Label("@nodejs//:node"),
        ),
        "_internal_yarn": attr.label(
            allow_single_file = True,
            default = Label("@nodejs//:bin/yarn"),
        ),
        "_internal_packages": attr.label(
            default = Label("//internal:packages"),
        ),
        "_js_script_compile_script": attr.label(
            allow_single_file = True,
            default = Label("//internal/js_script_and_test:compile.js"),
        ),
    },
    executable = True,
    outputs = {
        "compiled_dir": "%{name}_compiled_dir",
        "executable_file": "%{name}.sh",
    },
    implementation = _js_script_impl,
)

# js_test is identical to js_script, but it's marked as "test" instead of
# "executable".
js_test = rule(
    attrs = {
        "cmd": attr.string(
            mandatory = True,
        ),
        "lib": attr.label(
            providers = [JsLibraryInfo],
            mandatory = True,
        ),
        "_internal_nodejs": attr.label(
            allow_single_file = True,
            default = Label("@nodejs//:node"),
        ),
        "_internal_yarn": attr.label(
            allow_single_file = True,
            default = Label("@nodejs//:bin/yarn"),
        ),
        "_internal_packages": attr.label(
            default = Label("//internal:packages"),
        ),
        "_js_script_compile_script": attr.label(
            allow_single_file = True,
            default = Label("//internal/js_script_and_test:compile.js"),
        ),
    },
    outputs = {
        "compiled_dir": "%{name}_compiled_dir",
        "executable_file": "%{name}.sh",
    },
    test = True,
    implementation = _js_script_impl,
)
