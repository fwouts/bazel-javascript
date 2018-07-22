const fs = require("fs");
const path = require("path");
const webpack = require("webpack");

const [
  nodePath,
  scriptPath,
  htmlTemplatePath,
  loadersNpmPackagesDir,
  installedNpmPackagesDir,
  sourceDir,
  joinedAliases,
  joinedEnv,
  outputBundleDir,
  webpackConfigFilePath
] = process.argv;

const aliases = joinedAliases
  .split("|")
  .map(aliasTuple => aliasTuple.split(":", 2))
  .reduce((acc, [aliasName, aliasDir]) => {
    if (!aliasName) {
      // Happens when joinedAlias = "".
      return acc;
    }
    if (!fs.existsSync(aliasDir)) {
      throw new Error(
        `Missing source directory for module ${aliasName}: ${aliasDir}`
      );
      ``;
    }
    acc[aliasName] = path.resolve(aliasDir);
    return acc;
  }, {});

const env = joinedEnv
  .split("|")
  .map(envTuple => envTuple.split(":", 2))
  .reduce((acc, [name, value]) => {
    if (!name) {
      // Happens when joinedEnv = "".
      return acc;
    }
    acc[name] = JSON.stringify(value);
    return acc;
  }, {});

const configGenerator = require(path.resolve(webpackConfigFilePath));
const config = configGenerator(
  sourceDir,
  aliases,
  env,
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
    for (const error of info.errors) {
      console.log(error);
    }
    process.exit(1);
  }
  if (stats.hasWarnings()) {
    for (const error of info.warnings) {
      console.warn(error);
    }
  }
});
