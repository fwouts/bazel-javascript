const fs = require("fs-extra");
const path = require("path");

const DEFAULT_TSCONFIG = {
  compilerOptions: {
    target: "es2015",
    module: "es2015",
    moduleResolution: "node",
    declaration: true,
    strict: true,
    noImplicitAny: true,
    strictNullChecks: true,
    strictFunctionTypes: true,
    strictPropertyInitialization: true,
    noImplicitThis: true,
    alwaysStrict: true,
    jsx: "react",
    allowSyntheticDefaultImports: true,
    baseUrl: ".",
    paths: {
      "@/*": ["src/*"]
    }
  }
};

module.exports = async ({ package, into, inputs }) => {
  const inputFiles = inputs;
  if (inputFiles.length > 1) {
    throw new Error(`Got too many files for tsconfig generation ${inputFiles}`);
  }
  const tsconfigInput = inputFiles[0]
    ? JSON.parse(inputFiles[0].body)
    : DEFAULT_TSCONFIG;

  const compilerOptions = {};
  Object.assign(compilerOptions, tsconfigInput.compilerOptions || {});
  Object.assign(compilerOptions, {
    moduleResolution: "node",
    declaration: true,
    rootDir: "."
  });
  delete compilerOptions.allowJs;
  return [
    {
      path: "tsconfig.json",
      body: JSON.stringify({
        compilerOptions,
        exclude: ["node_modules"],
        include: [`${package.path}/**/*.ts`, `${package.path}/**/*.tsx`]
      })
    }
  ];
};
