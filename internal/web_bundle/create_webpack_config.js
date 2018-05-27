const fs = require("fs-extra");
const path = require("path");

const [
  nodePath,
  scriptPath,
  libBuildfilePath,
  entry,
  target,
  mode,
  optionalLibrary,
  splitChunksStr,
  webpackConfigPath
] = process.argv;

const [libraryName, libraryTarget] = optionalLibrary.split("/");
const splitChunks = splitChunksStr === "1";

const config = `const path = require("path");
const webpack = require("webpack");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');

module.exports = (
  sourceDir,
  outputBundleDir,
  installedNpmPackagesDir,
  loadersNpmPackagesDir,
  htmlTemplatePath,
) => ({
  entry: (sourceDir.startsWith("/") ? "" : "./") + path.join(
    sourceDir,
    path.dirname("${libBuildfilePath}"),
    "${entry}",
  ),
  output: {
    filename: "bundle.js",
    path: path.resolve(outputBundleDir),
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
  bail: ${mode === "production" ? "true" : "false"},
  target: "${target}",
  optimization: {
    ${
      mode === "production"
        ? `minimizer: [
      new UglifyJsPlugin({
        uglifyOptions: {
          parse: {
            ecma: 8,
          },
          compress: {
            ecma: 5,
            warnings: false,
            comparisons: false,
          },
          mangle: {
            safari10: true,
          },
          output: {
            ecma: 5,
            comments: false,
            ascii_only: true,
          },
        },
        parallel: true,
        cache: true,
        sourceMap: true,
      }),
      new OptimizeCSSAssetsPlugin(),
    ],`
        : ""
    }
    splitChunks: {
      chunks: 'all',
      name: 'vendors',
    },
    runtimeChunk: true,
  },
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
                  modules: true,
                  camelCase: true
                }
              }
            ]
          },
          {
            test: /\\.module\\.scss$/,
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
              "sass-loader"
            ]
          },
          {
            test: /\\.css$/,
            use: [
              "style-loader",
              "css-loader"
            ]
          },
          {
            test: /\\.scss$/,
            use: [
              "style-loader",
              {
                loader: "css-loader",
                options: {
                  importLoaders: 1
                }
              },
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
  node:
    ${JSON.stringify(
      {
        // Webpack complains when it encounters "module".
        module: "empty",
        // Some libraries import Node modules but don't use them in the browser.
        // Tell Webpack to provide empty mocks for them so importing them works.
        ...(target.indexOf("node") === -1 && {
          dgram: "empty",
          fs: "empty",
          net: "empty",
          tls: "empty",
          child_process: "empty",
          module: "empty"
        })
      },
      null,
      2
    )},
  resolve: {
    modules: [
      path.join(installedNpmPackagesDir, "node_modules"),
      // Necessary for webpack-hot-client with the dev server.
      path.join(loadersNpmPackagesDir, "node_modules")
    ]
  },
  resolveLoader: {
    modules: [
      path.join(loadersNpmPackagesDir, "node_modules")
    ]
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: htmlTemplatePath,
      inject: true,
      ${
        mode === "production"
          ? `minify: {
        removeComments: true,
        collapseWhitespace: true,
        removeRedundantAttributes: true,
        useShortDoctype: true,
        removeEmptyAttributes: true,
        removeStyleLinkTypeAttributes: true,
        keepClosingSlash: true,
        minifyJS: true,
        minifyCSS: true,
        minifyURLs: true,
      }`
          : ""
      }
    }),
    new webpack.DefinePlugin({
      NODE_ENV: "${mode}",
    }),
    ${
      mode === "production"
        ? `new MiniCssExtractPlugin({
      filename: 'static/css/[name].[contenthash:8].css',
      chunkFilename: 'static/css/[name].[contenthash:8].chunk.css',
    }),`
        : ""
    }
    ${
      // Chunk splitting is enabled by default.
      splitChunks
        ? `new webpack.optimize.LimitChunkCountPlugin({
      maxChunks: 1
    }),`
        : ""
    }
  ]
});
`;

fs.writeFileSync(webpackConfigPath, config, "utf8");
