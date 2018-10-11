const fs = require("fs-extra");
const path = require("path");
const {
  BazelAction,
  safeSymlink,
  ensureArray
} = require("../run_js/BazelAction");

/**
 * Action for creating a directory with the passed in files for symlinking and
 * copying.
 *
 * The files can follow a uri syntax with params:
 * recurse=false (default)
 * symlink=true (default)
 *
 *
 * The files to be populated have flags set on them for the appropriate actions:
 * [flags]:./file/path
 * Possible flags:
 * s: Symlink
 *   s:./some/dir/
 * c: Copy
 *   c:/some/file
 * r: Recurse
 *   rs:./some/dir/
 * m: Module (put it in node_modules)
 * mr: Recursive module (add all the modules to node_modules)
 * g: Generate (run the passed in script to generate source files
 *
 * eg. node create_source_dir.js -s file/to/symlink.
 */
BazelAction(
  {
    string: [
      // Root path to symlink/copy from
      "from",
      // The folder to populate
      "into"
    ]
  },
  async args => {
    const { current_target, workspace_name, package_path, from, into } = args;
    const sources = ensureArray(args._);
    const nodeModulesPath = path.join(into, "node_modules");
    const package = {
      workspace: workspace_name,
      path: package_path
    };

    makeDirectory(into);
    const existingDirs = new Set([into]);

    const populateFiles = async source => {
      const parsed = parseSource(source);
      console.dir(parsed);
      /**
       * Node Module Population
       */
      if (parsed.module) {
        if (parsed.recurse) {
          const fromNodeModulesDir = parsed.path;
          const allModuleDirectories = fs.readdirSync(fromNodeModulesDir);
          for (const moduleDirectory of allModuleDirectories) {
            if (isOrgScopeDirectory(moduleDirectory)) {
              const orgScopeFrom = path.join(
                fromNodeModulesDir,
                moduleDirectory
              );
              const orgScopeInto = path.join(nodeModulesPath, moduleDirectory);
              makeDirectory(orgScopeInto);
              const allOrgModuleDirectories = fs.readdirSync(orgScopeFrom);
              for (const orgModuleDirectory of allOrgModuleDirectories) {
                makeSymlink(
                  path.join(orgScopeFrom, orgModuleDirectory),
                  path.join(orgScopeInto, orgModuleDirectory)
                );
              }
            } else {
              makeSymlink(
                path.join(fromNodeModulesDir, moduleDirectory),
                path.join(nodeModulesPath, moduleDirectory)
              );
            }
          }
        }
      } else if (parsed.symlink) {
        makeSymlink(parsed.path, path.join(into, parsed.path));
      } else if (parsed.generate) {
        await makeGeneratedFiles(package, into, parsed.path, parsed.params);
      }
    };

    console.log(`Current Target: ${current_target}`);
    console.log(`Target Source Path: ${from}`);
    console.log(`Copying into: ${into}`);
    console.log(`Running in [${process.cwd()}]`);
    console.log(`Environment is: ${JSON.stringify(process.env, null, 2)}`);
    console.log(`Will create [${into}] for populating`);

    for (const source of sources) {
      await populateFiles(source);
    }

    // const internalDeps = joinedInternalDeps.split("|");
    // const srcs = joinedSrcs.split("|");

    //     fs.mkdirSync(into);
    //     safeSymlink(
    //       path.join(installedNpmPackagesDir, "node_modules"),
    //       path.join(destinationDir, "node_modules")
    //     );

    //     // Copy every internal dependency into the appropriate location.
    //     for (const internalDep of internalDeps) {
    //       if (!internalDep) {
    //         continue;
    //       }
    //       const [joinedSrcs, compiledDir] = internalDep.split(":");
    //       const srcs = joinedSrcs.split(";");
    //       for (const src of srcs) {
    //         if (!src) {
    //           continue;
    //         }
    //         safeSymlink(
    //           path.join(compiledDir, src),
    //           path.join(destinationDir, src)
    //         );
    //       }
    //     }

    //     // Extract compiler options from tsconfig.json, overriding anything other
    //     // than compiler options.
    //     const originalTsConfig = JSON.parse(fs.readFileSync(tsconfigPath, "utf8"));

    //     // Copy source code and update import statements in this target's sources.
    //     for (const src of srcs) {
    //       if (!src) {
    //         continue;
    //       }
    //       if (!fs.existsSync(src)) {
    //         console.error(`
    // Missing file ${src} required by ${targetLabel}.
    // `);
    //         process.exit(1);
    //       }
    //       const destinationFilePath = path.join(destinationDir, src);
    //       fs.ensureDirSync(path.dirname(destinationFilePath));
    //       safeSymlink(src, destinationFilePath);
    //     }

    //     const compilerOptions = {};
    //     Object.assign(compilerOptions, originalTsConfig.compilerOptions || {});
    //     Object.assign(compilerOptions, {
    //       moduleResolution: "node",
    //       declaration: true,
    //       rootDir: "."
    //     });
    //     fs.writeFileSync(
    //       path.join(destinationDir, "tsconfig.json"),
    //       JSON.stringify(
    //         {
    //           compilerOptions,
    //           files: srcs.filter(src => src.endsWith(".ts") || src.endsWith(".tsx"))
    //         },
    //         null,
    //         2
    //       ),
    //       "utf8"
    //     );
  }
);

function makeDirectory(directory) {
  fs.ensureDirSync(directory);
}

function makeSymlink(from, to) {
  fs.ensureSymlinkSync(from, to);
}

async function writeFile(into, output) {
  if (!path) {
    throw new Error(`Attempted to write file with no path set`);
  }
  await fs.writeFile(path.join(into, output.path), output.body);
}

async function makeGeneratedFiles(package, into, generatorScript, inputFiles) {
  const resolvedScript = path.join(process.cwd(), generatorScript);
  const generator = require(resolvedScript);
  if (!generator) {
    throw new Error(`No generator script found at ${generatorScript}`);
  }
  const inputFileContents = await Promise.all(
    inputFiles.map(async path => ({
      path,
      body: await fs.readFile(path)
    }))
  );
  const outputFiles = await generator({
    package,
    into,
    inputs: inputFileContents
  });
  await Promise.all(outputFiles.map(output => writeFile(into, output)));
}

function isOrgScopeDirectory(directory) {
  return directory.startsWith("@");
}

function parseSource(source) {
  const [flags, sourcePath, ...params] = source.split(":");
  const actions = { path: sourcePath, params };
  let flagIndex = 0;
  while (flagIndex < flags.length) {
    const currentFlag = flags[flagIndex];
    switch (currentFlag) {
      case "s":
        actions["symlink"] = true;
        break;
      case "c":
        actions["copy"] = true;
        break;
      case "r":
        actions["recurse"] = true;
        break;
      case "m":
        actions["module"] = true;
        break;
      case "g":
        actions["generate"] = true;
        break;
      default:
        throw new Error(
          `Encountered invalid flag "${currentFlag}" in "${source}"`
        );
    }
    flagIndex++;
  }
  if (actions.symlink && actions.copy) {
    throw new Error(`Attempted to both symlink and copy ${source}`);
  }
  return actions;
}
