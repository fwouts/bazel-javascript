const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

let arg = 0;

const [
  nodePath,
  scriptPath,
  buildfilePath,
  entry,
  installedWebpackDir,
  externalDepsDir,
  sourceDir,
  outputFile
] = process.argv;

const buildfileDir = path.dirname(buildfilePath);

fs.writeFileSync(
  path.join(installedWebpackDir, "webpack.config.js"),
  `const path = require("path");
const webpack = require("webpack");

module.exports = {
  entry: "./${path.relative(installedWebpackDir, path.join(sourceDir, entry))}",
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
      "${path.resolve(path.join(externalDepsDir, "node_modules"))}",
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
  `webpack-cli --output-path ${path.resolve(
    path.dirname(outputFile)
  )} --output-filename ${path.basename(outputFile)}`,
  {
    cwd: installedWebpackDir,
    stdio: "inherit",
    env: {
      PATH: path.dirname(nodePath) + ":./node_modules/.bin"
    }
  }
);
