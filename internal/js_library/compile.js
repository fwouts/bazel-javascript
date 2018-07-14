const fs = require("fs-extra");
const path = require("path");
const babel = require("babel-core");

const [nodePath, scriptPath, fullSrcDir, destinationDir] = process.argv;

// Copy over any non-JavaScript files (e.g. CSS assets) and internal modules.
fs.copySync(fullSrcDir, destinationDir, {
  dereference: true,
  filter: name => {
    return (
      path.basename(name) !== "node_modules" &&
      !name.endsWith(".es6") &&
      !name.endsWith(".js") &&
      !name.endsWith(".jsx")
    );
  }
});

// Compile with Babel.
transformDir(".");

function transformDir(dirRelativePath) {
  for (const fileName of fs.readdirSync(
    path.join(fullSrcDir, dirRelativePath)
  )) {
    const srcFilePath = path.join(fullSrcDir, dirRelativePath, fileName);
    if (fs.lstatSync(srcFilePath).isDirectory()) {
      transformDir(path.join(dirRelativePath, fileName));
    } else if (
      fileName.endsWith(".es6") ||
      fileName.endsWith(".js") ||
      fileName.endsWith(".jsx")
    ) {
      const transformed = babel.transformFileSync(srcFilePath, {
        plugins: [
          "transform-decorators-legacy",
          "transform-es2015-modules-commonjs"
        ],
        presets: ["env", "stage-2", "react"],
        ignore: "node_modules"
      });
      if (!transformed.code) {
        throw new Error(`Could not compile ${srcFilePath}.`);
      }
      const destFilePath = path.join(destinationDir, dirRelativePath, fileName);
      fs.ensureDirSync(path.dirname(destFilePath));
      fs.writeFileSync(destFilePath, transformed.code, "utf8");
    }
  }
}
