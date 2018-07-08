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

const config = `
const fs = require("fs");
const path = require("path");

module.exports = (
  sourceDir,
  outputBundleDir,
  installedNpmPackagesDir,
  loadersNpmPackagesDir,
  htmlTemplatePath,
) => {
  if (!fs.existsSync(sourceDir)) {
    throw new Error(\`Missing source directory: \${sourceDir}\`)
  }
  if (!fs.existsSync(installedNpmPackagesDir)) {
    throw new Error(\`Missing installed npm_modules directory: \${installedNpmPackagesDir}\`)
  }
  if (!fs.existsSync(loadersNpmPackagesDir)) {
    throw new Error(\`Missing loaders npm_modules directory: \${loadersNpmPackagesDir}\`)
  }
  if (!fs.existsSync(htmlTemplatePath)) {
    throw new Error(\`Missing HTML template: \${htmlTemplatePath}\`)
  }

  // We load webpack and its plugins from their absolute path instead of relying on Node's module loading
  // mechanism, because it would otherwise get confused and look in the local node_modules/ directory from which
  // Bazel is run, causing crashes for users who happen to also use NPM/Yarn directly.
  const webpack = require(path.resolve(\`\${loadersNpmPackagesDir}/node_modules/webpack\`));
  const HtmlWebpackPlugin = require(path.resolve(\`\${loadersNpmPackagesDir}/node_modules/html-webpack-plugin\`));
  const MiniCssExtractPlugin = require(path.resolve(\`\${loadersNpmPackagesDir}/node_modules/mini-css-extract-plugin\`));
  const OptimizeCSSAssetsPlugin = require(path.resolve(\`\${loadersNpmPackagesDir}/node_modules/optimize-css-assets-webpack-plugin\`));
  const UglifyJsPlugin = require(path.resolve(\`\${loadersNpmPackagesDir}/node_modules/uglifyjs-webpack-plugin\`));

  return {
    entry: (sourceDir.startsWith("/") ? "" : "./") + path.join(
      sourceDir,
      path.dirname("${libBuildfilePath}"),
      "${entry}",
    ),
    output: {
      filename: "bundle.js",
      path: path.resolve(outputBundleDir),
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
        target.indexOf("node") !== -1
          ? {
              // Webpack complains when it encounters "module".
              module: "empty"
            }
          : {
              // Webpack complains when it encounters "module".
              module: "empty",
              // Some libraries import Node modules but don't use them in the browser.
              // Tell Webpack to provide empty mocks for them so importing them works.
              dgram: "empty",
              fs: "empty",
              net: "empty",
              tls: "empty",
              child_process: "empty",
              module: "empty"
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
  };
}
`;

fs.writeFileSync(webpackConfigPath, config, "utf8");
