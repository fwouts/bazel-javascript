const fs = require("fs-extra");
const path = require("path");
const ts = require("typescript");

const [nodePath, scriptPath, fullSrcDir, destinationDir] = process.argv;

// Copy over any non-TypeScript files (e.g. CSS assets).
fs.copySync(fullSrcDir, destinationDir, {
  dereference: true,
  filter: name => {
    return (
      path.basename(name) !== "node_modules" &&
      !name.endsWith(".ts") &&
      !name.endsWith(".tsx")
    );
  }
});

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
