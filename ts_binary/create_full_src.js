const fs = require("fs-extra");
const path = require("path");

let arg = 0;

const nodePath = process.argv[arg++];
const scriptPath = process.argv[arg++];
const externalDepsDir = process.argv[arg++];
const srcDir = process.argv[arg++];
const entry = process.argv[arg++];
const destinationDir = process.argv[arg++];

fs.copySync(srcDir, destinationDir);
// Copy every external node_modules directory.
// TODO: Find a way to speed it up. Ideally, we would use fs.symlinkSync() instead
// since we only need readonly access to these modules, but it doesn't work, I suspect
// because externalDepsDir is a temporary symlink that stops existing as soon as this
// rule is done executing.
fs.copySync(
  path.join(externalDepsDir, "node_modules"),
  path.join(destinationDir, "node_modules")
);

fs.writeFileSync(
  path.join(destinationDir, "webpack.config.js"),
  `const path = require("path");
const webpack = require("webpack");

module.exports = {
  entry: "./${entry}",
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
    modules: [path.resolve(__dirname, "node_modules")],
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
