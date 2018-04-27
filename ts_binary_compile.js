const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

let arg = 0;

const nodePath = process.argv[arg++];
const scriptPath = process.argv[arg++];
const yarnPath = process.argv[arg++];
const entry = process.argv[arg++];
const srcDirPath = process.argv[arg++];
const externalDeps = process.argv[arg++].split("|");
const buildDirPath = process.argv[arg++];
const destFilePath = process.argv[arg++];

if (!fs.existsSync(path.join(srcDirPath, entry))) {
  throw new Error(`Missing entry: ${entry}.`);
}

fs.copySync(srcDirPath, buildDirPath, { dereference: true });

const dependencies = externalDeps.reduce((acc, curr) => {
  if (!curr) {
    return acc;
  }
  const atSignPosition = curr.lastIndexOf("@");
  if (atSignPosition === -1) {
    throw new Error(`Expected @ sign in ${curr}.`);
  }
  const package = curr.substr(0, atSignPosition);
  const version = curr.substr(atSignPosition + 1);
  if (acc[package] && acc[package] !== version) {
    throw new Error(
      `Mismatching versions of the same package ${package}: ${
        acc[package]
      } and ${version}.`
    );
  }
  return {
    ...acc,
    [package]: version
  };
}, {});
fs.writeFileSync(
  path.join(buildDirPath, "package.json"),
  JSON.stringify(
    {
      dependencies
    },
    null,
    2
  ),
  "utf8"
);

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

child_process.execSync(`${yarnPath} --cwd ${buildDirPath}`, {
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
