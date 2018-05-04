const fs = require("fs-extra");
const path = require("path");

const [
  nodePath,
  scriptPath,
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

if (fs.existsSync(path.join(installedNpmPackagesDir, "node_modules"))) {
  // Find all the packages we depend on indirectly. We'll only include those.
  const analyzedPackageNames = new Set();
  const toAnalyzePackageNames = Array.from(required);
  for (let i = 0; i < toAnalyzePackageNames.length; i++) {
    findPackageDependencies(toAnalyzePackageNames[i]);
  }
  function findPackageDependencies(name) {
    if (!name) {
      // Occurs when there are no dependencies.
      return;
    }
    if (analyzedPackageNames.has(name)) {
      // Already processed.
      return;
    }
    analyzedPackageNames.add(name);
    const packageJsonPath = path.join(
      installedNpmPackagesDir,
      "node_modules",
      name,
      "package.json"
    );
    if (!fs.existsSync(packageJsonPath)) {
      return;
    }
    try {
      const package = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
      if (!package.dependencies) {
        return;
      }
      for (const dependencyName of Object.keys(package.dependencies)) {
        toAnalyzePackageNames.push(dependencyName);
      }
    } catch (e) {
      console.warn(`Could not read package.json for package ${name}.`, e);
      return;
    }
  }

  // Create a symbolic link from node_modules.
  fs.mkdirSync(path.join(destinationDir, "node_modules"));
  for (const packageName of analyzedPackageNames) {
    if (packageName.indexOf("/") !== -1) {
      const [parentName, nestedPackageName] = packageName.split("/");
      fs.ensureDirSync(path.join(destinationDir, "node_modules", parentName));
    }
    fs.symlinkSync(
      path.join(installedNpmPackagesDir, "node_modules", packageName),
      path.join(destinationDir, "node_modules", packageName)
    );
  }
}

// Copy every internal dependency into the appropriate location.
const pathToPackagedPath = {};
for (const compiledDir of internalDeps) {
  if (!compiledDir) {
    continue;
  }
  fs.copySync(compiledDir, destinationDir, {
    dereference: true
  });
}

// Copy source code.
const srcsSet = new Set(srcs);
for (const sourceFilePath of srcs) {
  if (!sourceFilePath) {
    continue;
  }
  if (!fs.existsSync(sourceFilePath)) {
    throw new Error(`Missing file: ${sourceFilePath}.`);
  }
  const destinationFilePath = path.join(destinationDir, sourceFilePath);
  fs.ensureDirSync(path.dirname(destinationFilePath));
  fs.copySync(sourceFilePath, destinationFilePath);
}
