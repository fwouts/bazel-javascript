const fs = require("fs-extra");
const path = require("path");
const ts = require("typescript");
const { safeSymlink } = require("../common/symlink");

const [nodePath, scriptPath, fullSrcDir, destinationDir] = process.argv;

// Copy over any non-TypeScript files (e.g. CSS assets).
symlinkNonTypeScriptFiles(".");

// Transpile with TypeScript.
const config = JSON.parse(
  fs.readFileSync(path.join(fullSrcDir, "tsconfig.json"))
);
transpile(fullSrcDir);

function transpile(src) {
  const lstat = fs.lstatSync(fs.realpathSync(src));
  if (lstat.isFile()) {
    if (src.endsWith(".ts") || src.endsWith(".tsx")) {
      const output = ts.transpileModule(fs.readFileSync(src, "utf8"), config);
      const jsName =
        src.substr(0, src.length - (src.endsWith(".tsx") ? 4 : 3)) + ".js";
      fs.writeFileSync(
        path.join(destinationDir, path.relative(fullSrcDir, jsName)),
        output.outputText,
        "utf8"
      );
    }
  } else if (lstat.isDirectory()) {
    for (const f of fs.readdirSync(src)) {
      if (f === "node_modules") {
        continue;
      }
      transpile(path.join(src, f));
    }
  }
}

function symlinkNonTypeScriptFiles(dirRelativePath) {
  for (const fileName of fs.readdirSync(
    path.join(fullSrcDir, dirRelativePath)
  )) {
    const relativeFilePath = path.join(dirRelativePath, fileName);
    const srcFilePath = path.join(fullSrcDir, relativeFilePath);
    let destFilePath = path.join(destinationDir, relativeFilePath);
    fs.ensureDirSync(path.dirname(destFilePath));
    if (fs.lstatSync(srcFilePath).isDirectory()) {
      symlinkNonTypeScriptFiles(relativeFilePath);
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
