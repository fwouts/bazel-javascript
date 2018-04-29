const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");

const { runYarn, yarnShellCommand } = require("./ts_common/run_yarn");

let arg = 0;

const nodePath = process.argv[arg++];
const scriptPath = process.argv[arg++];
const yarnPath = process.argv[arg++];
const yarnPathShort = process.argv[arg++];
const cmd = process.argv[arg++];
const buildPath = process.argv[arg++];
const srcs = process.argv[arg++].split("|");
const externalDeps = process.argv[arg++].split("|");
const internalDeps = process.argv[arg++].split("|");
const destinationDir = process.argv[arg++];
const destinationDirShort = process.argv[arg++];
const executablePath = process.argv[arg++];

fs.mkdirSync(destinationDir);
for (const src of srcs) {
  const destPath = path.relative(path.dirname(buildPath), src);
  fs.ensureDirSync(path.dirname(path.join(destinationDir, destPath)));
  fs.copySync(src, path.join(destinationDir, destPath), { dereference: true });
}

const dependencies = externalDeps.reduce((acc, curr) => {
  if (!curr) {
    return acc;
  }
  const atSignPosition = curr.lastIndexOf("@");
  if (atSignPosition === -1) {
    throw new Error(`Expected @ sign in ${curr}.`);
  }
  const package = curr.substr(0, atSignPosition);
  const version = curr.substr(atSignPosition + 1);
  if (acc[package] && acc[package] !== version) {
    throw new Error(
      `Mismatching versions of the same package ${package}: ${
        acc[package]
      } and ${version}.`
    );
  }
  return {
    ...acc,
    [package]: version
  };
}, {});
fs.writeFileSync(
  path.join(destinationDir, "package.json"),
  JSON.stringify(
    {
      dependencies,
      scripts: {
        start: cmd
      }
    },
    null,
    2
  ),
  "utf8"
);

runYarn(yarnPath, destinationDir);

for (const internalDep of internalDeps) {
  const [targetPackage, targetName, compiledDir] = internalDep.split(":");
  const rootModuleName =
    "__" + targetPackage.replace(/\//g, "__") + "__" + targetName;
  fs.copySync(
    compiledDir,
    path.join(destinationDir, "node_modules", rootModuleName),
    {
      dereference: true
    }
  );
}

fs.writeFileSync(
  executablePath,
  `#!/bin/sh
chmod -R +w ${destinationDirShort}/*
${yarnShellCommand(yarnPathShort, destinationDirShort, "start")}
`,
  "utf8"
);
