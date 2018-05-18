const fs = require("fs-extra");
const path = require("path");
const webpack = require("webpack");

const [nodePath, scriptPath, webpackConfigFilePath] = process.argv;

webpack(require(path.resolve(webpackConfigFilePath)), (err, stats) => {
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
});
