load("//internal/common:context.bzl", "JsLibraryInfo", "JsModuleInfo", "JS_LIBRARY_ATTRIBUTES", "js_context")

def _js_module_impl(ctx):
    
    return [
        ctx.attr.lib[JsLibraryInfo],
        JsModuleInfo(
            name = ctx.label.name,
            single_file = ctx.attr.single_file,
        ),
    ]

js_module = rule(
    attrs = {
        "lib": attr.label(
            providers = [JsLibraryInfo],
            mandatory = True,
        ),
        "single_file": attr.string(),
    },
    implementation = _js_module_impl,
)
