const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

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

// Compile with TypeScript.
child_process.execSync(
  `${
    process.env.NODE_PATH
  }/.bin/tsc --project ${fullSrcDir} --outDir ${destinationDir}`,
  {
    stdio: "inherit"
  }
);
