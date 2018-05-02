// NOTE: install.js cannot depend on any NPM packages other than the standard
// Node API because it's what we use to install NPM packages.

const child_process = require("child_process");
const fs = require("fs");
const path = require("path");

const { runYarn } = require("../common/run_yarn");

const [
  nodePath,
  scriptPath,
  packageJsonPath,
  yarnLockPath,
  destinationDir
] = process.argv;

// Create the destination directory and copy package.json and yarn.lock.
fs.mkdirSync(destinationDir);
fs.writeFileSync(
  path.join(destinationDir, "package.json"),
  fs.readFileSync(packageJsonPath)
);
fs.writeFileSync(
  path.join(destinationDir, "yarn.lock"),
  fs.readFileSync(yarnLockPath)
);

// Run `yarn`, which will install packages from NPM into node_modules/.
runYarn(destinationDir);
