const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

const { yarnShellCommand } = require("../ts_common/run_yarn");

let arg = 0;

const [
  nodePath,
  scriptPath,
  yarnPath,
  yarnPathShort,
  cmd,
  externalDepsDir,
  externalDepsDirShort,
  buildfilePath,
  joinedSrcs,
  joinedInternalDeps,
  destinationDir,
  destinationDirShort,
  executablePath
] = process.argv;

const srcs = joinedSrcs.split("|");
const internalDeps = joinedInternalDeps.split("|");

fs.mkdirSync(destinationDir);
for (const src of srcs) {
  const destPath = path.relative(path.dirname(buildfilePath), src);
  fs.ensureDirSync(path.dirname(path.join(destinationDir, destPath)));
  fs.copySync(src, path.join(destinationDir, destPath));
}

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
        externalDepsDir
      )}", "node_modules"),
    ],
  },
};
`,
    "utf8"
  );
}

for (const internalDep of internalDeps) {
  const [targetPackage, targetName, compiledDir] = internalDep.split(":");
  const rootModuleName =
    "__" + targetPackage.replace(/\//g, "__") + "__" + targetName;
  fs.copySync(
    compiledDir,
    path.join(destinationDir, "node_modules", rootModuleName)
  );
}

fs.writeFileSync(
  executablePath,
  `#!/bin/sh
chmod -R +w ${destinationDirShort}/*
export PATH=$PATH:$PWD/${externalDepsDirShort}/node_modules/.bin
${yarnShellCommand(yarnPathShort, destinationDirShort, "start")}
`,
  "utf8"
);
