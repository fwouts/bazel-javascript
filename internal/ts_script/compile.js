const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

const { yarnShellCommand } = require("../ts_common/run_yarn");

const [
  nodePath,
  scriptPath,
  cmd,
  installedNpmPackagesDir,
  installedNpmPackagesDirShort,
  sourceDir,
  destinationDir,
  destinationDirShort,
  executablePath
] = process.argv;

fs.copySync(sourceDir, destinationDir);

// Create a package.json with a "scripts" section.
fs.writeFileSync(
  path.join(destinationDir, "package.json"),
  JSON.stringify(
    {
      scripts: {
        start: cmd
      }
    },
    null,
    2
  ),
  "utf8"
);

// TODO: Remove storybook exception.
if (fs.existsSync(path.join(destinationDir, ".storybook"))) {
  fs.writeFileSync(
    path.join(destinationDir, ".storybook", "webpack.config.js"),
    `const path = require("path");

module.exports = {
  resolve: {
    modules: [
      path.resolve(__dirname, "..", "node_modules"),
      path.resolve(__dirname, "..", "${path.relative(
        destinationDir,
        installedNpmPackagesDir
      )}", "node_modules"),
    ],
  },
  resolveLoader: {
    modules: [
      path.resolve(__dirname, "..", "${path.relative(
        destinationDir,
        installedNpmPackagesDir
      )}", "node_modules"),
    ],
  },
  module: {
    rules: [
      {
        test: /\.css$/,
        use: [
          "style-loader",
          "css-loader",
        ],
      },
    ],
  }
};
`,
    "utf8"
  );
}

// Generate a shell script that invokes `yarn start`.
fs.writeFileSync(
  executablePath,
  `#!/bin/sh
chmod -R +w ${destinationDirShort}/*
export PATH=$PATH:$PWD/${installedNpmPackagesDirShort}/node_modules/.bin
export NODE_PATH=${path.relative(
    destinationDirShort,
    installedNpmPackagesDirShort
  )}/node_modules
${yarnShellCommand(destinationDirShort, "start")}
`,
  "utf8"
);
