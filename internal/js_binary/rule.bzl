load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")
load("//internal/common:context.bzl", "JsLibraryInfo", "JS_LIBRARY_ATTRIBUTES", "js_context")

def _js_binary_impl(ctx):
    js = js_context(ctx)
    providers = []

    compile_args = js.script_args(js)

    ctx.actions.run(
        inputs = [
            ctx.file._js_binary_compile_script,
            ctx.attr._internal_packages[NpmPackagesInfo].installed_dir,
            ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir,
            ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir,
        ],
        outputs = [
            ctx.outputs.executable_file,
        ],
        executable = ctx.file._internal_nodejs,
        env = {
            "NODE_PATH": ctx.attr._internal_packages[NpmPackagesInfo].installed_dir.path + "/node_modules",
        },
        arguments = [
            # Run `node js_binary/compile.js`.
            ctx.file._js_binary_compile_script.path,
            # Path of the directory containing the lib's BUILD.bazel file.
            ctx.attr.lib[JsLibraryInfo].build_file_path,
            # Entry point for Webpack (e.g. "main.ts").
            ctx.attr.entry,
            # Mode for Webpack.
            ctx.attr.mode,
            # Directory containing external NPM dependencies the code depends on.
            ctx.attr.lib[JsLibraryInfo].npm_packages_installed_dir.path,
            # Directory containing the compiled source code of the js_library.
            ctx.attr.lib[JsLibraryInfo].compiled_javascript_dir.path,
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
    attrs = {
        "lib": attr.label(
            providers = [JsLibraryInfo],
            mandatory = True,
        ),
        "entry": attr.string(
            mandatory = True,
        ),
        "mode": attr.string(
            values = [
                "none",
                "development",
                "production",
            ],
            default = "none",
        ),
        "_internal_nodejs": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("@nodejs//:node"),
        ),
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
    implementation = _js_binary_impl,
)
