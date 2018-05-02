# Produced by npm_packages().
NpmPackagesInfo = provider(fields=[
  "installed_dir",
])

def _npm_packages_impl(ctx):
  ctx.actions.run_shell(
    inputs = [
      ctx.file._npm_packages_install,
      ctx.file.package_json,
      ctx.file.yarn_lock,
    ],
    outputs = [ctx.outputs.installed_dir],
    command = "node \"$@\"",
    use_default_shell_env = True,
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
      installed_dir = ctx.outputs.installed_dir
    ),
  ]

npm_packages = rule(
  implementation = _npm_packages_impl,
  attrs = {
    "package_json": attr.label(
      allow_files = True,
      single_file = True,
    ),
    "yarn_lock": attr.label(
      allow_files = True,
      single_file = True,
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
)

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
    )
  ]

npm_binary = rule(
  implementation = _npm_binary_impl,
  attrs = {
    "install": attr.label(
      providers = [NpmPackagesInfo],
    ),
    "binary": attr.string(),
  },
  outputs = {
    "bin": "%{name}.sh"
  },
  executable = True,
)
