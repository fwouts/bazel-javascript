const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");
const { safeSymlink } = require("../common/symlink");

const [nodePath, scriptPath, fullSrcDir, destinationDir] = process.argv;

// Copy over any non-TypeScript files (e.g. CSS assets).
copyNonTypeScriptFiles(".");

// Compile with TypeScript.
child_process.execSync(
  `${
    process.env.NODE_PATH
  }/.bin/tsc --project ${fullSrcDir} --outDir ${destinationDir}`,
  {
    stdio: "inherit"
  }
);

function copyNonTypeScriptFiles(dirRelativePath) {
  for (const fileName of fs.readdirSync(
    path.join(fullSrcDir, dirRelativePath)
  )) {
    const relativeFilePath = path.join(dirRelativePath, fileName);
    const srcFilePath = path.join(fullSrcDir, relativeFilePath);
    let destFilePath = path.join(destinationDir, relativeFilePath);
    fs.ensureDirSync(path.dirname(destFilePath));
    if (fs.lstatSync(srcFilePath).isDirectory()) {
      copyNonTypeScriptFiles(relativeFilePath);
    } else if (
      fileName !== "node_modules" &&
      !fileName.endsWith(".ts") &&
      !fileName.endsWith(".tsx")
    ) {
      // Symlink any file that isn't a TypeScript file (e.g. precompile JS or CSS assets).
      safeSymlink(srcFilePath, destFilePath);
    }
  }
}
