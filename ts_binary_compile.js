const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

const nodePath = process.argv[0];
const yarnPath = process.argv[2];
const entry = process.argv[3];
const srcDirPath = process.argv[4];
const buildDirPath = process.argv[5];
const destFilePath = process.argv[6];

if (!fs.existsSync(path.join(srcDirPath, entry))) {
  throw new Error(`Missing entry: ${entry}.`);
}

fs.copySync(srcDirPath, buildDirPath, { dereference: true });

fs.writeFileSync(
  path.join(buildDirPath, "webpack.config.js"),
  `const path = require("path");
const webpack = require("webpack");

module.exports = {
  entry: "./${entry}",
  output: {
    filename: "${path.basename(destFilePath)}",
    path: path.resolve(__dirname, "${path.relative(
      buildDirPath,
      path.dirname(destFilePath)
    )}"),
  },
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
    extensions: [".ts", ".tsx", ".js"],
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

child_process.execSync(`${yarnPath} add --cwd ${buildDirPath}`, {
  stdio: "inherit"
});

child_process.execSync(
  `${yarnPath} add --cwd ${buildDirPath} ts-loader typescript webpack webpack-cli`,
  {
    stdio: "inherit"
  }
);

fs.copySync(
  path.join(srcDirPath, "node_modules"),
  path.join(buildDirPath, "node_modules")
);

child_process.execSync("webpack-cli", {
  cwd: buildDirPath,
  stdio: "inherit",
  env: {
    PATH: path.dirname(nodePath) + ":./node_modules/.bin"
  }
});
