NpmPackagesInfo = provider(fields = [
    "installed_dir",
])

def _npm_packages_impl(ctx):
  ctx.actions.run(
    inputs = [
      ctx.file._npm_packages_install,
      ctx.file.package_json,
      ctx.file.yarn_lock,
    ],
    outputs = [ctx.outputs.installed_dir],
    executable = ctx.file._internal_nodejs,
    arguments = [
      # Run `node npm_packages/install.js`.
      ctx.file._npm_packages_install.path,
      # Path of package.json to install with.
      ctx.file.package_json.path,
      # Path of yarn.lock to lock versions.
      ctx.file.yarn_lock.path,
      # Path to install into (node_modules/ will be created there).
      ctx.outputs.installed_dir.path,
    ],
  )
  return [
    NpmPackagesInfo(
      installed_dir = ctx.outputs.installed_dir,
    ),
  ]

npm_packages = rule(
    attrs = {
        "package_json": attr.label(
            allow_files = True,
            single_file = True,
            mandatory = True,
        ),
        "yarn_lock": attr.label(
            allow_files = True,
            single_file = True,
            mandatory = True,
        ),
        "_internal_nodejs": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("@nodejs//:node"),
        ),
        "_npm_packages_install": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("//internal/npm_packages:install.js"),
        ),
    },
    outputs = {
        "installed_dir": "%{name}_installed_dir",
    },
    implementation = _npm_packages_impl,
)
