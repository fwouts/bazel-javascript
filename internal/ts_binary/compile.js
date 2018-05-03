const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

const [
  nodePath,
  scriptPath,
  entry,
  installedWebpackDir,
  installedNpmPackagesDir,
  compiledDir,
  buildDir,
  outputFile
] = process.argv;

// Create build directory.
fs.mkdirSync(buildDir);

// Create webpack.config.js in build directory.
//
// Note that we don't actually copy any sources in this directory.
// Instead, it refers to the existing source directory and node_modules
// directories (there are two: one containing webpack and other build tools,
// and another containing the actual code dependencies).
fs.writeFileSync(
  path.join(buildDir, "webpack.config.js"),
  `const path = require("path");
const webpack = require("webpack");

module.exports = {
  entry: "${path.relative(installedWebpackDir, path.join(compiledDir, entry))}",
  output: {
    filename: "${path.basename(outputFile)}",
    path: "${path.resolve(path.dirname(outputFile))}",
  },
  target: "node",
  resolve: {
    modules: [
      "${path.resolve(path.join(compiledDir, "node_modules"))}",
      "${path.resolve(path.join(installedNpmPackagesDir, "node_modules"))}",
      "${path.resolve(path.join(installedWebpackDir, "node_modules"))}",
    ],
  },
  plugins: [
    new webpack.BannerPlugin({
      banner: "#!/usr/bin/env node",
      raw: true,
    }),
  ],
};
`,
  "utf8"
);

child_process.execSync(
  `webpack-cli --config ${path.resolve(
    path.join(buildDir, "webpack.config.js")
  )}`,
  {
    cwd: installedWebpackDir,
    stdio: "inherit",
    env: {
      NODE_PATH: path.resolve(path.join(installedWebpackDir, "node_modules")),
      PATH: path.dirname(nodePath) + ":./node_modules/.bin"
    }
  }
);
