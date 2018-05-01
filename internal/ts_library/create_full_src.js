const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");
const ts = require("typescript");

const [
  nodePath,
  scriptPath,
  yarnPath,
  installedNpmPackagesDir,
  buildfilePath,
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

// Add tsconfig.json for future compilation.
fs.writeFileSync(
  path.join(destinationDir, "tsconfig.json"),
  JSON.stringify(
    {
      compilerOptions: {
        target: "esnext",
        module: "commonjs",
        moduleResolution: "node",
        declaration: true,
        strict: true,
        jsx: "react",
        allowSyntheticDefaultImports: true,
        baseUrl: ".",
        paths: {
          "*": [
            path.relative(
              path.join(destinationDir),
              path.join(installedNpmPackagesDir, "node_modules", "*")
            )
          ]
        }
      },
      exclude: ["node_modules"]
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
  const srcs = joinedSrcs.split("|");
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
for (const sourceFilePath of srcs) {
  if (!sourceFilePath) {
    continue;
  }
  if (!fs.existsSync(sourceFilePath)) {
    throw new Error(`Missing file: ${sourceFilePath}.`);
  }
  // TODO: Create directories recursively as required.
  const destinationFilePath = path.join(
    destinationDir,
    path.relative(buildfileDir, sourceFilePath)
  );
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
      let replaceWith;
      for (const potentialImportPath of Object.keys(pathToPackagedPath)) {
        if (path.join(buildfileDir, importFrom) === potentialImportPath) {
          replaceWith = pathToPackagedPath[potentialImportPath];
        }
      }
      if (!replaceWith) {
        if (importFrom.startsWith("./")) {
          // This must be a local import.
          // Compilation will fail if it's missing. No need to check here.
        } else {
          // This must be an external package.
          // TODO: Also handle workspace-level references, e.g. '@/src/etc'.
          let packageName;
          const splitImportFrom = importFrom.split("/");
          if (
            splitImportFrom.length >= 2 &&
            splitImportFrom[0].startsWith("@")
          ) {
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
        // It could well be a perfectly correct reference to an external module
        // or another file in the same target.
        // This will fail at compilation time if there is no match.
        continue;
      }
      statement.moduleSpecifier = ts.createLiteral(replaceWith);
    }
  }
  const updatedFile = ts.createPrinter().printFile(sourceFile);
  fs.writeFileSync(destinationFilePath, updatedFile, "utf8");
}
