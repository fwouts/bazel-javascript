const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

const [
  nodePath,
  scriptPath,
  buildfilePath,
  entry,
  installedWebpackDir,
  installedNpmPackagesDir,
  sourceDir,
  buildDir,
  outputFile
] = process.argv;

const buildfileDir = path.dirname(buildfilePath);

fs.mkdirSync(buildDir);
fs.writeFileSync(
  path.join(buildDir, "webpack.config.js"),
  `const path = require("path");
const webpack = require("webpack");

module.exports = {
  entry: "${path.relative(installedWebpackDir, path.join(sourceDir, entry))}",
  output: {
    filename: "${path.basename(outputFile)}",
    path: "${path.resolve(path.dirname(outputFile))}",
  },
  target: "node",
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: 'ts-loader',
        exclude: /node_modules/,
      },
    ],
  },
  resolve: {
    modules: [
      "${path.resolve(path.join(sourceDir, "node_modules"))}",
      "${path.resolve(path.join(installedNpmPackagesDir, "node_modules"))}",
      "${path.resolve(path.join(installedWebpackDir, "node_modules"))}",
    ],
    extensions: [".ts", ".tsx", ".js", ".jsx"],
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
