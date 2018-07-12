const fs = require("fs-extra");
const path = require("path");
const ts = require("typescript");

const [
  nodePath,
  scriptPath,
  targetLabel,
  installedNpmPackagesDir,
  tsconfigPath,
  joinedInternalDeps,
  joinedSrcs,
  destinationDir
] = process.argv;

const internalDeps = joinedInternalDeps.split("|");
const srcs = joinedSrcs.split("|");

fs.mkdirSync(destinationDir);
const oldWorkingDir = process.cwd();
process.chdir(destinationDir);
fs.symlinkSync(
  path.relative(
    destinationDir,
    path.join(installedNpmPackagesDir, "node_modules")
  ),
  "node_modules"
);
process.chdir(oldWorkingDir);

const validFilePaths = new Set();

// Copy every internal dependency into the appropriate location.
for (const internalDep of internalDeps) {
  if (!internalDep) {
    continue;
  }
  const [joinedSrcs, compiledDir] = internalDep.split(":");
  const srcs = joinedSrcs.split(";");
  for (const src of srcs) {
    if (!src) {
      continue;
    }
    validFilePaths.add(
      path.join(
        path.dirname(src),
        src.endsWith(".ts") || src.endsWith(".tsx")
          ? path.parse(src).name
          : path.basename(src)
      )
    );
  }
  fs.copySync(compiledDir, destinationDir, {
    dereference: true
  });
}

// Extract compiler options from tsconfig.json, overriding anything other
// than compiler options.
const originalTsConfig = JSON.parse(fs.readFileSync(tsconfigPath, "utf8"));

// Figure out what "@/..." imports should be relative to. What is "@"?
// TODO: Consider supporting other prefixes specified in tsconfig.paths.
// By default, "@/..." means it's relative to the workspace directory.
let atSignImportDir = ".";
let atSignPatterns;
if (
  originalTsConfig.compilerOptions &&
  originalTsConfig.compilerOptions.paths &&
  (atSignPatterns = originalTsConfig.compilerOptions.paths["@/*"])
) {
  if (atSignPatterns.length !== 1) {
    console.error(
      `
Multiple paths for "@/*" in tsconfig.json are not supported.
Please take a look at //${tsconfigPath} to fix this issue.
`
    );
    process.exit(1);
  }
  const atSignPattern = atSignPatterns[0];
  if (!atSignPattern.endsWith("/*")) {
    console.error(
      `
Path matcher ${atSignPattern} in tsconfig.json was expected to end with "/*".
Please take a look at //${tsconfigPath} to fix this issue.
`
    );
    process.exit(1);
  }
  // Find where the directory pointed to is. This is relative to baseUrl, which
  // is itself related to tsconfig.json's path.
  atSignImportDir = path.join(
    path.dirname(tsconfigPath),
    originalTsConfig.compilerOptions.baseUrl || ".",
    atSignPattern.substr(0, atSignPattern.length - 2)
  );
}

// Copy source code and update import statements in this target's sources.
const srcsSet = new Set(srcs);
for (const src of srcs) {
  if (!src) {
    continue;
  }
  if (!fs.existsSync(src)) {
    console.error(`
Missing file ${src} required by ${targetLabel}.
`);
    process.exit(1);
  }
  const destinationFilePath = path.join(destinationDir, src);
  fs.ensureDirSync(path.dirname(destinationFilePath));
  if (
    !destinationFilePath.endsWith(".ts") &&
    !destinationFilePath.endsWith(".tsx")
  ) {
    // Assets and other non-TypeScript files should simply be copied.
    fs.copySync(src, destinationFilePath);
    continue;
  }
  const sourceText = fs.readFileSync(src, "utf8");
  const sourceFile = ts.createSourceFile(
    path.basename(src),
    sourceText,
    ts.ScriptTarget.Latest,
    true
  );
  for (const statement of sourceFile.statements) {
    // TODO: Also handle require statements.
    if (statement.kind === ts.SyntaxKind.ImportDeclaration) {
      const importFrom = statement.moduleSpecifier.text;
      if (
        importFrom.startsWith("./") ||
        importFrom.startsWith("../") ||
        importFrom.startsWith("@/")
      ) {
        let importPathFromWorkspace;
        if (importFrom[0] === "@") {
          // Workspace-level import, e.g. "@/src/some/path".
          importPathFromWorkspace = path.join(
            atSignImportDir,
            importFrom.substr(2)
          );
        } else {
          importPathFromWorkspace = path.join(path.dirname(src), importFrom);
        }
        let replaceWith;
        if (validFilePaths.has(importPathFromWorkspace)) {
          // Found a match.
          replaceWith =
            "./" + path.relative(path.dirname(src), importPathFromWorkspace);
        } else if (validFilePaths.has(importPathFromWorkspace + "/index")) {
          // Found a match (index of a directory).
          replaceWith =
            "./" + path.relative(path.dirname(src), importPathFromWorkspace);
        } else {
          // This must be a local import (in the same target).
          // It could either be a TypeScript import, in which case the
          // extension will have been omitted, or it could be an asset such
          // as a CSS stylesheet, in which case the extension does not need
          // to be appended.
          const candidateEndings = [".ts", ".tsx", ""];
          let foundMatch = false;
          for (const candidateEnding of candidateEndings) {
            if (srcsSet.has(importPathFromWorkspace + candidateEnding)) {
              // Good, the file exists.
              foundMatch = true;
              break;
            }
          }
          if (!foundMatch) {
            // Try index too.
            for (const candidateEnding of candidateEndings) {
              if (
                srcsSet.has(
                  importPathFromWorkspace + "/index" + candidateEnding
                )
              ) {
                // Good, the file exists.
                foundMatch = true;
                break;
              }
            }
          }
          if (foundMatch) {
            // Make sure to replace any absolute imports such as "@/src/some/path"
            // with relative imports, so we don't need to deal with them at a later
            // stage.
            replaceWith =
              "./" + path.relative(path.dirname(src), importPathFromWorkspace);
          } else {
            console.error(`
Could not find a match for import "${importFrom}".
Are you missing a source file or a dependency in ${targetLabel}?
`);
            process.exit(1);
          }
        }
        statement.moduleSpecifier = ts.createLiteral(replaceWith);
      } else {
        // This must be an external package.
      }
    }
  }
  const updatedFile = ts.createPrinter().printFile(sourceFile);
  fs.writeFileSync(destinationFilePath, updatedFile, "utf8");
}

const compilerOptions = {};
Object.assign(compilerOptions, originalTsConfig.compilerOptions || {});
Object.assign(compilerOptions, {
  moduleResolution: "node",
  declaration: true,
  rootDir: "."
});
fs.writeFileSync(
  path.join(destinationDir, "tsconfig.json"),
  JSON.stringify(
    {
      compilerOptions,
      files: srcs.filter(src => src.endsWith(".ts") || src.endsWith(".tsx"))
    },
    null,
    2
  ),
  "utf8"
);
