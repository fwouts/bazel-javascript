const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");
const ts = require("typescript");

const { dependenciesMap } = require("./dependencies_map");
const { runYarn } = require("./run_yarn");

const [
  nodePath,
  scriptPath,
  yarnPath,
  joinedExternalDependencies,
  destinationDir
] = process.argv;

const externalDependencies = dependenciesMap(
  joinedExternalDependencies.split("|")
);

// Create an empty directory with package.json.
fs.mkdirSync(destinationDir);
fs.writeFileSync(
  path.join(destinationDir, "package.json"),
  JSON.stringify(
    {
      dependencies: externalDependencies
    },
    null,
    2
  ),
  "utf8"
);

// Run yarn to download dependencies.
runYarn(yarnPath, destinationDir);
