const child_process = require("child_process");
const path = require("path");

let arg = 0;

const nodePath = process.argv[arg++];
const scriptPath = process.argv[arg++];
const buildDir = path.dirname(process.argv[arg++]);
const sourceDir = process.argv[arg++];
const outputFile = process.argv[arg++];

child_process.execSync(
  `webpack-cli --output-path ${path.resolve(
    path.dirname(outputFile)
  )} --output-filename ${path.basename(outputFile)}`,
  {
    cwd: sourceDir,
    stdio: "inherit",
    env: {
      PATH: path.dirname(nodePath) + ":./node_modules/.bin"
    }
  }
);
