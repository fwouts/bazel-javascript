const fs = require("fs-extra");
const path = require("path");
const { safeSymlink } = require("../common/symlink");

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
safeSymlink(
  path.join(installedNpmPackagesDir, "node_modules"),
  path.join(destinationDir, "node_modules")
);

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
    safeSymlink(path.join(compiledDir, src), path.join(destinationDir, src));
  }
}

// Extract compiler options from tsconfig.json, overriding anything other
// than compiler options.
const originalTsConfig = JSON.parse(fs.readFileSync(tsconfigPath, "utf8"));

// Copy source code and update import statements in this target's sources.
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
  safeSymlink(src, destinationFilePath);
}

const compilerOptions = {};
Object.assign(compilerOptions, originalTsConfig.compilerOptions || {});
Object.assign(compilerOptions, {
  moduleResolution: "node",
  declaration: true,
  rootDir: "."
});
delete compilerOptions.allowJs;
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
