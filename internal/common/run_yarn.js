const child_process = require("child_process");

function runYarn(cwd, command = "") {
  const exitCode = child_process.execSync(yarnShellCommand(cwd, command), {
    stdio: "inherit"
  });
}

function yarnShellCommand(cwd, command = "") {
  // Don't use the shared cache or touch the lockfile.
  // See https://github.com/yarnpkg/yarn/issues/986.
  return `yarn --cwd ${cwd} --ignore-scripts --frozen-lockfile --cache-folder ./node_modules_cache --global-folder ./node_modules/ ${command}`;
}

module.exports = {
  runYarn,
  yarnShellCommand
};
