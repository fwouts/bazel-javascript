const fs = require("fs-extra");
const path = require("path");
const ts = require("typescript");
const { safeSymlink } = require("../common/symlink");

const [
  nodePath,
  scriptPath,
  targetLabel,
  joinedAliases,
  joinedInternalDeps,
  joinedSrcs,
  destinationDir
] = process.argv;

const aliases = joinedAliases
  .split("|")
  .map(joinedAlias => joinedAlias.split(":", 2))
  .reduce((acc, [name, path]) => {
    acc[name] = path;
    return acc;
  }, {});
const internalDeps = joinedInternalDeps.split("|");
const srcs = joinedSrcs.split("|");

fs.mkdirSync(destinationDir);

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
        src.endsWith(".es6") || src.endsWith(".js") || src.endsWith(".jsx")
          ? path.parse(src).name
          : path.basename(src)
      )
    );
    safeSymlink(path.join(compiledDir, src), path.join(destinationDir, src));
  }
}

// Copy source code.
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
    !destinationFilePath.endsWith(".es6") &&
    !destinationFilePath.endsWith(".js") &&
    !destinationFilePath.endsWith(".jsx")
  ) {
    // Assets and other non-JavaScript files should simply be copied.
    safeSymlink(src, destinationFilePath);
    continue;
  }
  const sourceText = fs.readFileSync(src, "utf8");
  const sourceFile = ts.createSourceFile(
    path.basename(src),
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.JSX
  );
  for (const statement of sourceFile.statements) {
    // TODO: Also handle require statements.
    if (statement.kind === ts.SyntaxKind.ImportDeclaration) {
      let importFrom = statement.moduleSpecifier.text;
      let ignoreMissingMatch = false;
      if (aliases[importFrom]) {
        importFrom = aliases[importFrom];
        // For now, we don't require rules to define explicit dependencies for aliases.
        ignoreMissingMatch = true;
        if (importFrom.startsWith("//")) {
          importFrom = "@/" + importFrom.substr(2);
        }
      }
      if (
        importFrom.startsWith("./") ||
        importFrom.startsWith("../") ||
        importFrom.startsWith("@/")
      ) {
        let importPathFromWorkspace;
        if (importFrom[0] === "@") {
          // Workspace-level import, e.g. "@/src/some/path".
          importPathFromWorkspace = importFrom.substr(2);
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
          // It could either be a JavaScript import, in which case the
          // extension will have been omitted, or it could be an asset such
          // as a CSS stylesheet, in which case the extension does not need
          // to be appended.
          const candidateEndings = [".es6", ".js", ".jsx", ""];
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
          } else if (ignoreMissingMatch) {
            // Pretend that we've found a match.
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
