const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");
const webpack = require("webpack");

const [
  nodePath,
  scriptPath,
  entry,
  mode,
  installedNpmPackagesDir,
  compiledDir,
  outputFile
] = process.argv;

webpack(
  {
    entry: path.resolve(path.join(compiledDir, entry)),
    output: {
      filename: path.basename(outputFile),
      path: path.resolve(path.dirname(outputFile))
    },
    mode,
    target: "node",
    resolve: {
      modules: [
        path.resolve(path.join(compiledDir, "__internal_node_modules")),
        path.resolve(path.join(installedNpmPackagesDir, "node_modules"))
      ]
    }
  },
  (err, stats) => {
    // See https://webpack.js.org/api/node/#error-handling.
    if (err) {
      console.error(err.stack || err);
      if (err.details) {
        console.error(err.details);
      }
      process.exit(1);
    }
    const info = stats.toJson();
    if (stats.hasErrors()) {
      console.error(info.errors);
      process.exit(1);
    }
    if (stats.hasWarnings()) {
      console.warn(info.warnings);
    }
  }
);
