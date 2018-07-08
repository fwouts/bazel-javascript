const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

const [nodePath, scriptPath, fullSrcDir, destinationDir] = process.argv;

// Copy over any non-JavaScript files (e.g. CSS assets) and internal modules.
fs.copySync(fullSrcDir, destinationDir, {
  dereference: true,
  filter: name => {
    return (
      path.basename(name) !== "node_modules" &&
      !name.endsWith(".js") &&
      !name.endsWith(".jsx")
    );
  }
});

// Compile with Babel.
child_process.execSync(
  `${
    process.env.NODE_PATH
  }/.bin/babel ${fullSrcDir} --presets env,stage-2,react --plugins transform-es2015-modules-commonjs --ignore node_modules --out-dir ${destinationDir}`,
  {
    stdio: "inherit"
  }
);
