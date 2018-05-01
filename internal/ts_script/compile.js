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
  buildfilePath,
  joinedSrcs,
  joinedInternalDeps,
  destinationDir,
  destinationDirShort,
  executablePath
] = process.argv;

const srcs = joinedSrcs.split("|");
const internalDeps = joinedInternalDeps.split("|");

// Copy all sources, making sure to keep their relative location to the BUILD
// file that included them.
fs.mkdirSync(destinationDir);
for (const src of srcs) {
  const destPath = path.relative(path.dirname(buildfilePath), src);
  fs.ensureDirSync(path.dirname(path.join(destinationDir, destPath)));
  fs.copySync(src, path.join(destinationDir, destPath));
}

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
};
`,
    "utf8"
  );
}

// Copy every internal module we depend on to node_modules/.
// We don't need to worry about external NPM dependencies here, because the
// shell script below will mention their node_modules path.
for (const internalDep of internalDeps) {
  const [targetPackage, targetName, compiledDir] = internalDep.split(":");
  const rootModuleName =
    "__" + targetPackage.replace(/\//g, "__") + "__" + targetName;
  fs.copySync(
    compiledDir,
    path.join(destinationDir, "node_modules", rootModuleName)
  );
}

// Generate a shell script that invokes `yarn start`.
fs.writeFileSync(
  executablePath,
  `#!/bin/sh
chmod -R +w ${destinationDirShort}/*
export PATH=$PATH:$PWD/${installedNpmPackagesDirShort}/node_modules/.bin
${yarnShellCommand(destinationDirShort, "start")}
`,
  "utf8"
);
