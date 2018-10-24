load("//internal/common/actions:actions.bzl", "create_source_dir", "run_js")
load("//internal/npm_packages:rule.bzl", "NpmPackagesInfo")

###############################################################################
# Providers

# The Providers used are inspired by the rules_go providers:
# https://github.com/bazelbuild/rules_go/blob/master/go/providers.rst#GoLibrary

# Wrapper for rule ctx that should be created through js_context
JsContext = provider()

JsLibraryInfo = provider(
    fields = [
        "js",
        # The label that produced the JsLibrary
        "label",
        # Path of the BUILD.bazel file relative to the workspace root.
        "package_path",
        # Source files provided as input.
        "srcs",
        # All source files provided as input
        "all_sources",
        # Entire paths to add to npm modules (eg. a node_modules path)
        "node_modules_dirs",
        # Modules that  are depended upon directly
        "dep_modules",
        # Transitive module dependencies
        "all_dep_modules",
        # The target directories for the dependent modules
        "dep_module_targets",
        # The target directories for the transitive and directly dependent modules
        "all_dep_module_targets",
    ],
)
"""Metadata about an individual js library.

This provider keeps track of bazel information for Javascript targets, such
as: module dependencies, source files, paths to merge into node_modules.
"""

JsSourceInfo = provider(fields = [
    "js",
    # The source js files
    "srcs",
    # List of scripts to output
    "gen_scripts",
    # The library rule that generated this source
    "library",
])
"""Source that will be used either directly or for transpilation to javascript
"""

JsModuleInfo = provider(
    fields = [
        "js",
        # The root of the workspace
        "workspace_name",
        # The root directory of the module
        "module_root",
        # Name that will be used for non-relative imports
        "module_name",
        # Modules that this module directly depends on
        "dep_modules",
        # All modules that this module and its dependencies require
        "all_dep_modules",
        # The target directories for the dependent modules
        "dep_module_targets",
        # The target directories for the transitive and directly dependent modules
        "all_dep_module_targets",
    ],
)
""" Wraps a JsLibrary with a package_name for nonrelative imports

Including this as a dependency should add the "package_name" as a key for
nonrelative imports
"""

JsModuleMap = provider(
    fields = [
        "module_map",
    ],
)

###############################################################################
# Common Attributes

# Attributes that should be included for any rule that wants to create a JsContext
JS_CONTEXT_ATTRIBUTES = {
    "_actions_bazel_action_js": attr.label(
        allow_files = True,
        single_file = True,
        default = Label("//internal/common/actions/run_js:BazelAction.js"),
    ),
    "_create_source_dir_js": attr.label(
        allow_files = True,
        single_file = True,
        default = Label("//internal/common/actions/create_source_dir:create_source_dir.js"),
    ),
    "_internal_nodejs": attr.label(
        allow_files = True,
        single_file = True,
        default = Label("@nodejs//:node"),
    ),
    "_internal_packages": attr.label(
        default = Label("//internal:packages"),
    ),
    "_empty_npm_packages": attr.label(
        allow_files = True,
        single_file = True,
        default = Label("//internal/npm_packages/empty:packages"),
    ),
}

# Attributes that should be included for any rule that wants to create a JsLibrary
JS_LIBRARY_ATTRIBUTES = dict(JS_CONTEXT_ATTRIBUTES, **{
    "srcs": attr.label_list(
        allow_files = True,
        mandatory = True,
    ),
    "deps": attr.label_list(
        default = [],
    ),
    "module_name": attr.string(),
})

RULES_NODEJS_MODULE_ATTRIBUTES = {
    # The official bazel rules use module_name and module_root for non-relative
    # module mapping. If the module_root is supplied and the module_name is not
    # present then the module_name is assumed to be the target name. See:
    # https://github.com/bazelbuild/rules_nodejs/blob/master/internal/common/module_mappings.bzl
    "module_name": attr.string(),
    "module_root": attr.string(),
    # The official bazel rules look for this tag
    "tags": ["NODE_MODULE_MARKER"],
}

###############################################################################
# Helpers

def _js_library_info(js, attr = None):
    """Create a JsLibrary provider with attr.srcs and the sources from attr.deps

    Args:
    js: JsContext object
    attr: rule attributes to extract srcs and deps from
    """

    if not attr:
        attr = js.attr

    # The srcs should contain what has been explicitly added for a rule
    src_files = js._ctx.files.srcs

    # The deps is list of labels that should have providers that we can get sources from
    deps_attr = getattr(attr, "deps", [])

    transitive_sources = []
    node_modules_dirs = []
    dep_modules = []
    transitive_dep_modules = []
    dep_module_targets = []
    transitive_dep_module_targets = []

    # Iterate through the deps to add them to their correct JsLibrary attributes
    for dep in deps_attr:
        if JsLibraryInfo in dep:
            dep_js_library = dep[JsLibraryInfo]

            # The dependency is another JsLibrary
            transitive_sources.append(dep_js_library.all_sources)
            transitive_dep_modules.append(dep_js_library.all_dep_modules)
        elif JsModuleInfo in dep:
            dep_js_module = dep[JsModuleInfo]
            transitive_dep_modules.append(dep_js_module.all_dep_modules)
            transitive_dep_module_targets.append(dep_js_module.all_dep_module_targets)
        elif hasattr(dep, "tags") and "NODE_MODULES_MARKER" in getattr(dep, "tags"):
            # The dependency is a module defined by rules_nodejs
            direct_modules += dep

        if JsModuleInfo in dep:
            dep_js_module = dep[JsModuleInfo]
            dep_module_targets.append(dep_js_module.module_root)
            dep_modules.append(dep_js_module)

        if NpmPackagesInfo in dep:
            # The dependency is a node_modules directory installed by npm_packages
            node_modules_dirs.append(dep[NpmPackagesInfo].installed_dir)

    all_src_files = depset(
        direct = src_files,
        transitive = transitive_sources,
    )

    all_dep_modules = depset(
        direct = dep_modules,
        transitive = transitive_dep_modules,
    )

    all_dep_module_targets = depset(
        direct = dep_module_targets,
        transitive = transitive_dep_module_targets,
    )

    return JsLibraryInfo(
        js = js,
        package_path = js.package_path,
        srcs = src_files,
        all_sources = all_src_files,
        node_modules_dirs = node_modules_dirs,
        dep_modules = dep_modules,
        all_dep_modules = all_dep_modules,
        dep_module_targets = dep_module_targets,
        all_dep_module_targets = all_dep_module_targets,
    )

def _library_to_source_info(js, library, gen_scripts = None):
    """Create a JsSource provider for a given library
    The library is a target, but this resolves the actual source files needed
    to build the js library.
    """

    return JsSourceInfo(
        js = js,
        srcs = library.all_sources,
        gen_scripts = gen_scripts,
        library = library,
    )

def _library_to_module_info(js, library, module_root, module_name):
    return JsModuleInfo(
        js = js,
        workspace_name = js.workspace_name,
        all_dep_modules = library.all_dep_modules,
        all_dep_module_targets = library.all_dep_module_targets,
        module_root = module_root,
        module_name = module_name,
    )

def _script_args(js, script_file):
    """Create Args object that can be used with js.run_js()

    Args:
    js: JsContext object
    script_file: File object for the script to be run
    """
    if script_file == None:
        fail("No script file provided to script args")

    args = js.actions.args()

    # If the args get too big then spill over into the param file
    args.use_param_file("--param=%s")
    args.set_param_file_format("multiline")

    # args.add(script_file)

    args.add("--current_target", js.label)
    args.add("--workspace_name", js.workspace_name)
    args.add("--package_path", js.package_path)

    return args

def _module_mappings(js):
    """Get the hash of {module_name - module_root}

    The underlying function from rules_nodejs goes through all the
    dependencies looking for
    """
    print("The nodejs rules don't export the module mappings")
    # get_module_mappings(js.label, js.attr)

# Following pattern similar to rules_go
# https://github.com/bazelbuild/rules_go/blob/2179a6e1b576fc2a309c6cf677ad40e5b7f999ba/go/private/context.bzl#L207
def js_context(ctx, attr = None):
    if not attr:
        attr = ctx.attr

    # Node js to be used to run javascript backed bazel actions
    _internal_nodejs = getattr(ctx.file, "_internal_nodejs")

    # Packages that will be made available to javascript backed bazel actions
    _internal_packages = getattr(attr, "_internal_packages")

    # Packages that will be used if none are provided
    _empty_npm_packages = getattr(attr, "_empty_npm_packages")

    _actions_bazel_action_js = getattr(ctx.file, "_actions_bazel_action_js")
    _create_source_dir_js = getattr(ctx.file, "_create_source_dir_js")

    return JsContext(
        # Base Context
        label = ctx.label,
        attr = ctx.attr,

        # Fields
        workspace_name = ctx.workspace_name,
        package_path = ctx.label.package,
        module_name = getattr(attr, "module_name", None),
        _ctx = ctx,
        _internal_nodejs = _internal_nodejs,
        _internal_packages = _internal_packages,
        _empty_npm_packages = _empty_npm_packages,
        _actions_bazel_action_js = _actions_bazel_action_js,
        _create_source_dir_js = _create_source_dir_js,

        # Actions
        actions = ctx.actions,
        create_source_dir = create_source_dir,
        run_js = run_js,

        # Helpers
        script_args = _script_args,
        library_info = _js_library_info,
        library_to_source_info = _library_to_source_info,
        library_to_module_info = _library_to_module_info,
    )
