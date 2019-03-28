const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

const { yarnShellCommand } = require("../common/run_yarn");

const [
  nodePath,
  scriptPath,
  cmd,
  installedNpmPackagesDir,
  installedNpmPackagesDirShort,
  sourceDir,
  destinationDir,
  destinationDirShort,
  libBuildfilePath,
  executablePath,
  yarnPath
] = process.argv;

fs.copySync(sourceDir, destinationDir);

// Create a package.json with a "scripts" section.
fs.writeFileSync(
  path.join(destinationDir, "package.json"),
  JSON.stringify(
    {
      scripts: {
        start: cmd
      },
      babel: {
        presets: []
      }
    },
    null,
    2
  ),
  "utf8"
);

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
export GENDIR=${process.env.GENDIR}
export LIB_DIR=${path.dirname(libBuildfilePath)}
${yarnShellCommand(yarnPath, destinationDirShort, "start")}
`,
  "utf8"
);
