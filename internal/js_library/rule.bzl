load("//internal/common:context.bzl", "JS_LIBRARY_ATTRIBUTES", "js_context")

def _js_library_impl(ctx):
    js = js_context(ctx)
    providers = []

    js_library = js.library_info(js)
    providers.append(js_library)

    js_source = js.library_to_source_info(js, js_library)
    
    js.create_source_dir(js, js_source, ctx.outputs.compilation_src_dir)

    compile_args = js.script_args(js)
    compile_args.add("--srcDir", ctx.outputs.compilation_src_dir)
    compile_args.add("--outDir", ctx.outputs.compiled_dir)
    compile_args.add_all(js_library.all_sources)

    js_compile_inputs = depset(
        direct = [ctx.outputs.compilation_src_dir],
        transitive = [js_library.all_sources],
    )

    js.run_js(
        js,
        inputs = js_compile_inputs,
        outputs = [ctx.outputs.compiled_dir],
        script = ctx.file._js_library_compile_script,
        script_args = compile_args,
    )

    return providers

js_library = rule(
    attrs = dict(JS_LIBRARY_ATTRIBUTES, **{
        "_js_library_create_full_src_script": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("//internal/js_library:create_full_src.js"),
        ),
        "_js_library_compile_script": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("//internal/js_library:compile.js"),
        ),
    }),
    outputs = {
        "compilation_src_dir": "%{name}_compilation_src",
        "compiled_dir": "%{name}_compiled",
    },
    implementation = _js_library_impl,
)
