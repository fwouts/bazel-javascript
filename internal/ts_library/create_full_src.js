const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");
const ts = require("typescript");

const [
  nodePath,
  scriptPath,
  installedNpmPackagesDir,
  buildfilePath,
  tsconfigPath,
  joinedRequires,
  joinedInternalDeps,
  joinedSrcs,
  destinationDir
] = process.argv;

const buildfileDir = path.dirname(buildfilePath);
const required = new Set(joinedRequires.split("|"));
const internalDeps = joinedInternalDeps.split("|");
const srcs = joinedSrcs.split("|");

fs.mkdirSync(destinationDir);

// Extract compiler options from tsconfig.json, overriding anything other
// than compiler options.
const originalTsConfig = JSON.parse(fs.readFileSync(tsconfigPath, "utf8"));
fs.writeFileSync(
  path.join(destinationDir, "tsconfig.json"),
  JSON.stringify(
    {
      compilerOptions: {
        ...originalTsConfig.compilerOptions,
        baseUrl: ".",
        paths: {
          "*": [
            path.relative(
              path.join(destinationDir),
              path.join(installedNpmPackagesDir, "node_modules", "*")
            )
          ]
        }
      }
    },
    null,
    2
  ),
  "utf8"
);

// We will need to match every "import './relative/path'" to a non-relative
// import path, so that every dependency another Bazel rule can find it in the
// node_modules directory.
const pathToPackagedPath = {};

fs.mkdirSync(path.join(destinationDir, "node_modules"));

// Types must be copied, as TypeScript struggles with finding type definitions
// for scoped modules, e.g. @types/storybook__react.
if (
  fs.existsSync(path.join(installedNpmPackagesDir, "node_modules", "@types"))
) {
  fs.copySync(
    path.join(installedNpmPackagesDir, "node_modules", "@types"),
    path.join(destinationDir, "node_modules", "@types")
  );
}

// Copy every internal dependency into the appropriate node_modules/ subdirectory.
for (const internalDep of internalDeps) {
  if (!internalDep) {
    continue;
  }
  const [
    targetPackage,
    targetName,
    joinedSrcs,
    compiledDir
  ] = internalDep.split(":");
  const srcs = joinedSrcs.split(";");
  const rootModuleName =
    "__" + targetPackage.replace(/\//g, "__") + "__" + targetName;
  for (const src of srcs) {
    if (!src) {
      continue;
    }
    pathToPackagedPath[
      path.join(path.dirname(src), path.parse(src).name)
    ] = path.join(
      rootModuleName,
      path.relative(targetPackage, path.dirname(src)),
      path.parse(src).name
    );
  }
  fs.copySync(
    compiledDir,
    path.join(destinationDir, "node_modules", rootModuleName)
  );
}

// Update import statements in this target's sources.
const srcsSet = new Set(srcs);
for (const sourceFilePath of srcs) {
  if (!sourceFilePath) {
    continue;
  }
  if (!fs.existsSync(sourceFilePath)) {
    throw new Error(`Missing file: ${sourceFilePath}.`);
  }
  const destinationFilePath = path.join(
    destinationDir,
    path.relative(buildfileDir, sourceFilePath)
  );
  fs.ensureDirSync(path.dirname(destinationFilePath));
  if (
    !destinationFilePath.endsWith(".ts") &&
    !destinationFilePath.endsWith(".tsx")
  ) {
    // Assets and other non-TypeScript files should simply be copied.
    fs.copySync(sourceFilePath, destinationFilePath);
    continue;
  }
  const sourceText = fs.readFileSync(sourceFilePath, "utf8");
  const sourceFile = ts.createSourceFile(
    path.basename(sourceFilePath),
    sourceText,
    ts.ScriptTarget.Latest,
    true
  );
  for (const statement of sourceFile.statements) {
    // TODO: Also handle require statements.
    if (statement.kind === ts.SyntaxKind.ImportDeclaration) {
      const importFrom = statement.moduleSpecifier.text;
      if (importFrom.startsWith("./") || importFrom.startsWith("@/")) {
        let importPathFromWorkspace;
        if (importFrom[0] === "@") {
          // Workspace-level import, e.g. "@/src/some/path".
          importPathFromWorkspace = importFrom.substr(2);
        } else {
          importPathFromWorkspace = path.join(
            path.dirname(sourceFilePath),
            importFrom
          );
        }
        let replaceWith;
        for (const potentialImportPath of Object.keys(pathToPackagedPath)) {
          if (importPathFromWorkspace === potentialImportPath) {
            replaceWith = pathToPackagedPath[potentialImportPath];
          }
        }
        if (!replaceWith) {
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
          if (foundMatch) {
            // Make sure to replace any absolute imports such as "@/src/some/path"
            // with relative imports, so we don't need to deal with them at a later
            // stage.
            replaceWith =
              "./" +
              path.relative(
                path.dirname(sourceFilePath),
                importPathFromWorkspace
              );
          } else {
            throw new Error(`Could not find a match for import ${importFrom}.`);
          }
        }
        statement.moduleSpecifier = ts.createLiteral(replaceWith);
      } else {
        // This must be an external package.
        // TODO: Also handle workspace-level references, e.g. '@/src/etc'.
        let packageName;
        const splitImportFrom = importFrom.split("/");
        if (splitImportFrom.length >= 2 && splitImportFrom[0].startsWith("@")) {
          // Example: @storybook/react.
          packageName = splitImportFrom[0] + "/" + splitImportFrom[1];
        } else {
          // Example: react.
          packageName = splitImportFrom[0];
        }
        if (!required.has(packageName)) {
          throw new Error(`Undeclared dependency: ${packageName}.`);
        }
      }
    }
  }
  const updatedFile = ts.createPrinter().printFile(sourceFile);
  fs.writeFileSync(destinationFilePath, updatedFile, "utf8");
}
