load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

def _npm_binary_impl(ctx):
    # Generate a simple shell script that starts the binary, loaded from the
    # node_modules/.bin directory.
    ctx.actions.write(
        output = ctx.outputs.bin,
        content = "%s/node_modules/.bin/%s" % (
            ctx.attr.install[NpmPackagesInfo].installed_dir.short_path,
            ctx.attr.binary,
        ),
        is_executable = True,
    )
    return [
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = [
                    ctx.attr.install[NpmPackagesInfo].installed_dir,
                ],
            ),
            executable = ctx.outputs.bin,
        ),
    ]

npm_binary = rule(
    attrs = {
        "install": attr.label(
            providers = [NpmPackagesInfo],
            mandatory = True,
        ),
        "binary": attr.string(
            mandatory = True,
        ),
    },
    executable = True,
    outputs = {
        "bin": "%{name}.sh",
    },
    implementation = _npm_binary_impl,
)
