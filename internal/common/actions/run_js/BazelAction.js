const fs = require("fs-extra");
const getopts = require("getopts");
const path = require("path");
const readline = require("readline");

/**
 * Wrap a callback that will be called with the script arguments
 *
 * The arguments passed to the callback have only the arguments intended for
 * the script and have removed any escaping created by the run_js_action bazel
 * rule.
 *
 * The opts.args will be passed to the options parser.
 *
 * @param { { args: Object } } opts
 * @param {(ctx: { args: Object }) => void | Promise<void>} cb
 */
async function BazelAction(opts, cb) {
  try {
    const args = await parseBazelArgs(opts.args);
    await cb(args);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}

/**
 * Reads in param file produced by bazel
 *
 * The param file format should be "multiline"
 *
 * @param {string} filePath
 */
function readParamFile(filePath) {
  return new Promise((resolve, reject) => {
    try {
      const rl = readline.createInterface({
        input: fs.createReadStream(filePath),
        terminal: false,
        crlfDelay: Infinity
      });

      argfileArgs = [];

      rl.on("line", line => argfileArgs.push(line));
      rl.on("close", () => resolve(argfileArgs));
    } catch (e) {
      reject(e);
    }
  });
}

/**
 * Wrap the passed in argument in an array or return the argument if it is
 * already an array
 *
 * @param {any} arrayOrFirstElement
 */
function ensureArray(arrayOrFirstElement) {
  if (Array.isArray(arrayOrFirstElement)) {
    return arrayOrFirstElement;
  } else {
    return [arrayOrFirstElement];
  }
}

/**
 * Merge the two objects, if both objects have the same key then the values are
 * concatenated into an array.
 * @param {Object} into
 * @param {Object} from
 */
function mergeArgs(into, from) {
  for (const argName in from) {
    if (into[argName]) {
      into[argName] = ensureArray(into[argName]).concat(from[argName]);
    } else {
      into[argName] = from[argName];
    }
  }
  return into;
}

/**
 * Parse shell arguments with automatic handling for --params {paramFile}
 *
 * Uses mri (basically same options as minimist) to parse args. If there is a
 * parmeter --params={paramFile} in the arguments, then the param file will
 * automatically be read and the arguments in it returned in the
 *
 * @param {Object} opts Options for getopts (https://www.npmjs.com/package/getopts)
 * @param {string[]} args Array of arguments to parse (defaults to process.argv.slice(2))
 * @returns {{[argName: string]: ArgValue}} Object with arg names as keys
 */
async function parseBazelArgs(opts) {
  const result = getopts(process.argv.slice(2), opts);

  // --params was chosen as the use_param_file param_file_arg to match precident in rules_go
  // https://github.com/bazelbuild/rules_go/blob/2179a6e1b576fc2a309c6cf677ad40e5b7f999ba/go/private/context.bzl#L87
  if (result.params) {
    const argFileArgs = await readParamFile(result.params);
    const argfileResult = getopts(argFileArgs, opts);
    mergeArgs(result, argfileResult);
  }

  return result;
}

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
  safeSymlink,
  ensureArray,
  BazelAction
};
