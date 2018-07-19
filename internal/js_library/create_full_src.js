const fs = require("fs-extra");
const path = require("path");
const { safeSymlink } = require("../common/symlink");

const [
  nodePath,
  scriptPath,
  targetLabel,
  joinedInternalDeps,
  joinedSrcs,
  destinationDir
] = process.argv;

const internalDeps = joinedInternalDeps.split("|");
const srcs = joinedSrcs.split("|");

fs.mkdirSync(destinationDir);

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

// Copy source code.
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
  safeSymlink(src, destinationFilePath);
}
