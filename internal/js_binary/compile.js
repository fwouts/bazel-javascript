const { BazelAction } = require("../common/actions/run_js/BazelAction");
const path = require("path");
const webpack = require("webpack");

BazelAction(
  {},
  async ({
    srcDir,
    outDir,
    libBuildfilePath,
    entry,
    mode,
    installedNpmPackagesDir,
    compiledDir,
    outputFile
  }) => {
    webpack(
      {
        entry: path.resolve(
          path.join(compiledDir, path.dirname(libBuildfilePath), entry)
        ),
        output: {
          filename: path.basename(outputFile),
          path: path.resolve(path.dirname(outputFile))
        },
        mode,
        target: "node",
        resolve: {
          modules: [
            path.resolve(path.join(installedNpmPackagesDir, "node_modules"))
          ]
        },
        plugins: [
          new webpack.BannerPlugin({
            banner: "#!/usr/bin/env node",
            raw: true
          })
        ]
      },
      (err, stats) => {
        // See https://webpack.js.org/api/node/#error-handling.
        if (err) {
          console.error(err.stack || err);
          if (err.details) {
            console.error(err.details);
          }
          process.exit(1);
        }
        const info = stats.toJson();
        if (stats.hasErrors()) {
          console.error(info.errors);
          process.exit(1);
        }
        if (stats.hasWarnings()) {
          console.warn(info.warnings);
        }
      }
    );
  }
);
