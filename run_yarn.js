const child_process = require("child_process");

function runYarn(yarnPath, cwd, command = "") {
  child_process.execSync(yarnShellCommand(yarnPath, cwd, command), {
    stdio: "inherit"
  });
}

function yarnShellCommand(yarnPath, cwd, command = "") {
  // Don't use the shared cache or touch the lockfile.
  // See https://github.com/yarnpkg/yarn/issues/986.
  return `${yarnPath} --cwd ${cwd} --frozen-lockfile --cache-folder ./node_modules_cache --global-folder ./node_modules/ ${command}`;
}

module.exports = {
  runYarn,
  yarnShellCommand
};
