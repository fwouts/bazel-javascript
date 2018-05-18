const fs = require("fs-extra");
const path = require("path");

const [
  nodePath,
  scriptPath,
  libBuildfilePath,
  entry,
  htmlTemplatePath,
  target,
  mode,
  optionalLibrary,
  splitChunksStr,
  loadersNpmPackagesDir,
  installedNpmPackagesDir,
  sourceDir,
  outputBundleDir,
  webpackConfigPath
] = process.argv;

const [libraryName, libraryTarget] = optionalLibrary.split("/");
const splitChunks = splitChunksStr === "1";

const config = `const path = require("path");
const webpack = require("webpack");
const HtmlWebpackPlugin = require("html-webpack-plugin");

module.exports = {
  entry: path.resolve("${path.join(
    sourceDir,
    path.dirname(libBuildfilePath),
    entry
  )}"),
  output: {
    filename: "bundle.js",
    path: path.resolve("${outputBundleDir}"),
    publicPath: "/",
    ${
      optionalLibrary
        ? `library: "${libraryName}",
    libraryTarget: "${libraryTarget}",
    `
        : ""
    }
  },
  mode: "${mode}",
  target: "${target}",
  module: {
    rules: [
      {
        oneOf: [
          {
            test: /\\.module\\.css$/,
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
            test: /\\.module\\.scss$/,
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
            test: /\\.css$/,
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
            test: /\\.scss$/,
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
          },
          {
            // Exclude \`js\` files to keep "css" loader working as it injects
            // its runtime that would otherwise be processed through "file" loader.
            // Also exclude \`html\` and \`json\` extensions so they get processed
            // by webpacks internal loaders.
            exclude: [/\\.(js|jsx|mjs)$/, /\\.html$/, /\\.json$/],
            use: "file-loader"
          }
        ]
      }
    ]
  },
  // Some libraries import Node modules but don't use them in the browser.
  // Tell Webpack to provide empty mocks for them so importing them works.
  node:
    ${JSON.stringify(
      target.indexOf("node") === -1
        ? {
            dgram: "empty",
            fs: "empty",
            net: "empty",
            tls: "empty",
            child_process: "empty"
          }
        : {},
      null,
      2
    )},
  resolve: {
    modules: [
      path.resolve("${path.join(installedNpmPackagesDir, "node_modules")}")
    ]
  },
  resolveLoader: {
    modules: [
      path.resolve("${path.join(loadersNpmPackagesDir, "node_modules")}")
    ]
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: path.resolve("${htmlTemplatePath}"),
      inject: true
    }),
    ${
      // Chunk splitting is enabled by default.
      splitChunks
        ? ""
        : `new webpack.optimize.LimitChunkCountPlugin({
      maxChunks: 1
    }),`
    }
  ]
};
`;

fs.writeFileSync(webpackConfigPath, config, "utf8");
