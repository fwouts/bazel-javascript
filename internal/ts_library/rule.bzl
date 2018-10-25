load("//internal/js_library:rule.bzl", "JsLibraryInfo")
load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")
load("//internal/common:context.bzl", "JS_LIBRARY_ATTRIBUTES", "js_context")

TsLibraryInfo = provider(fields = [
    # Directory containing the TypeScript files (and potentially other assets).
    "original_typescript_dir",
    # Source files provided as input.
    "typescript_source_files",
    # Directory containing the generated TypeScript definitions and compiled JavaScript.
    "compiled_typescript_dir",
])

def _ts_library_impl(ctx):
    js = js_context(ctx)
    providers = []

    js_library = js.library_info(js)
    providers.append(js_library)

    js_source = js.library_to_source_info(js, js_library, gen_scripts = [
        [ctx.file._ts_config_genscript, ctx.file.tsconfig],
    ])
    providers.append(js_source)

    js.create_source_dir(js, js_source, ctx.outputs.compilation_src_dir)

    if js.module_name:
        js_module = js.library_to_module_info(
            js,
            js_library,
            module_name = js.module_name,
            module_root = ctx.outputs.compiled_dir,
        )
        providers.append(js_module)

    compile_args = js.script_args(js)
    compile_args.add("--project", ctx.outputs.compilation_src_dir)
    compile_args.add("--outDir", ctx.outputs.compiled_dir)

    ts_compile_inputs = depset(
        direct = [ctx.outputs.compilation_src_dir],
        transitive = [],
    )

    js.run_js(
        js,
        inputs = ts_compile_inputs,
        outputs = [ctx.outputs.compiled_dir],
        script = ctx.file._ts_library_compile_script,
        script_args = compile_args,
    )

    return providers

ts_library = rule(
    implementation = _ts_library_impl,
    attrs = dict(JS_LIBRARY_ATTRIBUTES, **{
        "tsconfig": attr.label(
            allow_files = [".json"],
            single_file = True,
            default = Label("//internal/ts_library:default_tsconfig.json"),
        ),
        "_ts_library_create_full_src_script": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("//internal/ts_library:create_full_src.js"),
        ),
        "_ts_library_compile_script": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("//internal/ts_library:compile.js"),
        ),
        "_ts_library_transpile_script": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("//internal/ts_library:transpile.js"),
        ),
        "_ts_config_genscript": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("//internal/ts_library:tsconfig.gen.js"),
        ),
    }),
    outputs = {
        "compilation_src_dir": "%{name}_compilation_src",
        "compiled_dir": "%{name}_compiled",
        # "transpilation_src_dir": "%{name}_transpilation_src",
        # "transpiled_dir": "%{name}_transpiled",
    },
)
