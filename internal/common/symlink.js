const fs = require("fs-extra");
const path = require("path");

function safeSymlink(fromPath, toPath) {
  const oldWorkingDir = process.cwd();
  const destinationPathDir = path.dirname(toPath);
  fs.ensureDirSync(destinationPathDir);
  process.chdir(destinationPathDir);
  fs.symlinkSync(
    path.relative(destinationPathDir, fromPath),
    path.basename(toPath)
  );
  process.chdir(oldWorkingDir);
}

module.exports = {
  safeSymlink
};
