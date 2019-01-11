def _map_modules(js_module_info):
    return "%s/%s:%s" % (js_module_info.module_root.path, js_module_info.js.package_path, js_module_info.module_name)

def create_source_dir(js, js_source, create_dir):
    """Creates a directory with the sources described in the JsSource object

    Args:
      js: JsContext object
      js_source: JsSource object describing the sources to symlink in the directory
      create_dir: File object to populate with the sources (eg. ctx.outputs.compilation_src_dir)

    Returns:
      Array with JsSource provider in it
    """

    library = js_source.library
    gen_scripts = []
    if js_source.gen_scripts:
        gen_scripts += js_source.gen_scripts

    direct_inputs = []
    direct_inputs += library.node_modules_dirs
    transitive_inputs = [library.all_sources]
    # Depset with all of the sources in it

    script_args = js.script_args(js)
    script_args.add("--into", create_dir)
    script_args.add("--from", js.package_path)

    for gen_script in gen_scripts:
        if type(gen_script) == type(""):
            direct_inputs.append(gen_script)
            script_args.add("g:./{}".format(gen_script.path))
        elif type(gen_script) == type([]) and len(gen_script) > 0:
            argValue = "g"
            for value in gen_script:
                direct_inputs.append(value)
                argValue += ":./{}".format(value.path)
            script_args.add(argValue)

    script_args.add_all(library.all_sources, format_each = "s:%s")
    script_args.add_all(library.node_modules_dirs, format_each = "mrs:%s/node_modules/")
    script_args.add_all(library.all_dep_modules, map_each = _map_modules, format_each = "m:%s")

    inputs = depset(
        direct = direct_inputs,
        transitive = [library.all_sources, library.all_dep_module_targets],
    )

    js.run_js(js, inputs = inputs, outputs = [create_dir], script = js._create_source_dir_js, script_args = script_args)
