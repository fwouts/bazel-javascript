const child_process = require("child_process");
const fs = require("fs-extra");
const path = require("path");
const webpack = require("webpack");

const [
  nodePath,
  scriptPath,
  libBuildfilePath,
  entry,
  target,
  mode,
  splitChunksStr,
  publicPath,
  loadersNpmPackagesDir,
  installedNpmPackagesDir,
  compiledDir,
  outputBundleDir
] = process.argv;

const splitChunks = splitChunksStr === "1";

webpack(
  {
    entry: path.resolve(
      path.join(compiledDir, path.dirname(libBuildfilePath), entry)
    ),
    output: {
      filename: "bundle.js",
      path: path.resolve(outputBundleDir),
      publicPath: publicPath || undefined
    },
    mode,
    target,
    module: {
      rules: [
        {
          test: /\.module\.css$/,
          use: [
            "style-loader",
            {
              loader: "css-loader",
              options: {
                importLoaders: 1,
                modules: true,
                camelCase: true
              }
            },
            "postcss-loader"
          ]
        },
        {
          test: /\.module\.scss$/,
          use: [
            "style-loader",
            {
              loader: "css-loader",
              options: {
                importLoaders: 2,
                modules: true,
                camelCase: true
              }
            },
            "postcss-loader",
            "sass-loader"
          ]
        },
        {
          test: /\.css$/,
          exclude: /\.module\.css$/,
          use: [
            "style-loader",
            {
              loader: "css-loader",
              options: {
                importLoaders: 1
              }
            },
            "postcss-loader"
          ]
        },
        {
          test: /\.scss$/,
          exclude: /\.module\.scss$/,
          use: [
            "style-loader",
            {
              loader: "css-loader",
              options: {
                importLoaders: 2
              }
            },
            "postcss-loader",
            "sass-loader"
          ]
        }
      ]
    },
    // Some libraries import Node modules but don't use them in the browser.
    // Tell Webpack to provide empty mocks for them so importing them works.
    node:
      target.indexOf("node") === -1
        ? {
            dgram: "empty",
            fs: "empty",
            net: "empty",
            tls: "empty",
            child_process: "empty"
          }
        : {},
    resolve: {
      modules: [
        path.resolve(path.join(installedNpmPackagesDir, "node_modules"))
      ]
    },
    resolveLoader: {
      modules: [path.resolve(path.join(loadersNpmPackagesDir, "node_modules"))]
    },
    plugins: splitChunks
      ? [
          // By default, Webpack splits chunks.
        ]
      : [
          // If we don't have a public path, we can't split chunks because we
          // wouldn't know where to load them from.
          new webpack.optimize.LimitChunkCountPlugin({
            maxChunks: 1
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
