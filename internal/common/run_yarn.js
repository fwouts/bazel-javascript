const child_process = require("child_process");

function runYarn(cwd, command = "") {
  child_process.execSync(yarnShellCommand(cwd, command), {
    stdio: "inherit"
  });
}

function yarnShellCommand(cwd, command = "") {
  // Don't use the shared cache or touch the lockfile.
  // See https://github.com/yarnpkg/yarn/issues/986.
  return `yarn --cwd ${cwd} --ignore-scripts --frozen-lockfile ${command}`;
}

module.exports = {
  runYarn,
  yarnShellCommand
};
