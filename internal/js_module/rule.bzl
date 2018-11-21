load("//internal/js_library:rule.bzl", "JsLibraryInfo")

JsModuleInfo = provider(fields = [
    "name",
    "single_file",
])

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
