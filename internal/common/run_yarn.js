const child_process = require("child_process");
const fs = require("fs");

const CACHE_PATH = "/tmp/bazel_node_modules_cache";

function runYarn(cwd, command = "") {
  if (!fs.existsSync(CACHE_PATH)) {
    fs.mkdirSync(CACHE_PATH);
  }
  child_process.execSync(yarnShellCommand(cwd, command), {
    stdio: "inherit"
  });
}

function yarnShellCommand(cwd, command = "") {
  // Don't use the shared cache or touch the lockfile.
  // See https://github.com/yarnpkg/yarn/issues/986.
  return `yarn --cwd ${cwd} --ignore-scripts --cache-folder ${CACHE_PATH} --frozen-lockfile ${command}`;
}

module.exports = {
  runYarn,
  yarnShellCommand
};
