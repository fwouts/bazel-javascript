const {
  BazelAction,
  safeSymlink
} = require("../common/actions/run_js/BazelAction");
const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");
const babel = require("babel-core");

BazelAction({}, async ({ srcDir, outDir }) => {
  const srcs = new Set(joinedSrcs.split("|"));

  function transformDir(dirRelativePath) {
    currentDir = path.join(srcDir, dirRelativePath);
    for (const fileName of fs.readdirSync(currentDir)) {
      const relativeFilePath = path.join(dirRelativePath, fileName);
      const srcFilePath = path.join(srcDir, relativeFilePath);
      let destFilePath = path.join(outDir, relativeFilePath);
      fs.ensureDirSync(path.dirname(destFilePath));
      if (fs.lstatSync(srcFilePath).isDirectory()) {
        transformDir(relativeFilePath);
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
        if (!destFilePath.endsWith(".js")) {
          destFilePath =
            destFilePath.substr(0, destFilePath.lastIndexOf(".")) + ".js";
        }
        fs.writeFileSync(destFilePath, transformed.code, "utf8");
      } else {
        // Symlink any file that:
        // - isn't a source file of this package; or
        // - is not a JavaScript file (e.g. CSS assets).
        safeSymlink(srcFilePath, destFilePath);
      }
    }
  }

  // Compile with Babel.
  transformDir(".");
});

const [nodePath, scriptPath, fullSrcDir, outDir, joinedSrcs] = process.argv;
