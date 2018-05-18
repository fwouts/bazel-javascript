const path = require("path");
const webpack = require("webpack");

const [
  nodePath,
  scriptPath,
  htmlTemplatePath,
  loadersNpmPackagesDir,
  installedNpmPackagesDir,
  sourceDir,
  outputBundleDir,
  webpackConfigFilePath
] = process.argv;

const configGenerator = require(path.resolve(webpackConfigFilePath));
const config = configGenerator(
  sourceDir,
  outputBundleDir,
  installedNpmPackagesDir,
  loadersNpmPackagesDir,
  htmlTemplatePath
);

webpack(config, (err, stats) => {
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
