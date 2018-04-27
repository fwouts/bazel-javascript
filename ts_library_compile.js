const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");
const ts = require("typescript");

let arg = 0;

const nodePath = process.argv[arg++];
const scriptPath = process.argv[arg++];
const yarnPath = process.argv[arg++];
const tscPath = process.argv[arg++];
const buildfileDir = path.dirname(process.argv[arg++]);
const externalDeps = process.argv[arg++].split("|");
const internalDeps = process.argv[arg++].split("|");
const srcs = process.argv[arg++].split("|");
const destinationDir = process.argv[arg++];
const compilationDir = process.argv[arg++];

const dependencies = externalDeps.reduce((acc, curr) => {
  if (!curr) {
    return acc;
  }
  const atSignPosition = curr.lastIndexOf("@");
  if (atSignPosition === -1) {
    throw new Error(`Expected @ sign in ${curr}.`);
  }
  const package = curr.substr(0, atSignPosition);
  const version = curr.substr(atSignPosition + 1);
  if (acc[package] && acc[package] !== version) {
    throw new Error(
      `Mismatching versions of the same package ${package}: ${
        acc[package]
      } and ${version}.`
    );
  }
  return {
    ...acc,
    [package]: version
  };
}, {});

fs.mkdirSync(destinationDir);
fs.mkdirSync(path.join(destinationDir, "node_modules"));
fs.writeFileSync(
  path.join(destinationDir, "package.json"),
  JSON.stringify(
    {
      dependencies
    },
    null,
    2
  ),
  "utf8"
);
fs.writeFileSync(
  path.join(destinationDir, "tsconfig.json"),
  JSON.stringify(
    {
      compilerOptions: {
        target: "esnext",
        module: "esnext",
        moduleResolution: "node",
        declaration: true,
        strict: true,
        jsx: "preserve",
        esModuleInterop: true,
        outDir: path.resolve(compilationDir)
      },
      exclude: ["node_modules"]
    },
    null,
    2
  ),
  "utf8"
);

child_process.execSync(`${yarnPath} --cwd ${destinationDir}`, {
  stdio: "inherit"
});

const pathToPackagedPath = {};

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
    path.join(destinationDir, "node_modules", rootModuleName),
    {
      dereference: true
    }
  );
}

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
          if (!dependencies[packageName]) {
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

child_process.execSync(path.resolve(tscPath), {
  stdio: "inherit",
  cwd: destinationDir
});
