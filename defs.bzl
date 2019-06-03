load("//internal/js_binary:rule.bzl", _js_binary = "js_binary")
load(
    "//internal/js_library:rule.bzl",
    _JsLibraryInfo = "JsLibraryInfo",
    _js_library = "js_library",
)
load("//internal/js_module:rule.bzl", _js_module = "js_module")
load(
    "//internal/js_script_and_test:rule.bzl",
    _js_script = "js_script",
    _js_test = "js_test",
)
load("//internal/npm_binary:rule.bzl", _npm_binary = "npm_binary")
load(
    "//internal/npm_packages:rule.bzl",
    _NpmPackagesInfo = "NpmPackagesInfo",
    _npm_packages = "npm_packages",
)
load("//internal/ts_library:rule.bzl", _ts_library = "ts_library")
load("//internal/web_bundle:rule.bzl", _web_bundle = "web_bundle")

JsLibraryInfo = _JsLibraryInfo
js_binary = _js_binary
js_library = _js_library
js_module = _js_module
js_script = _js_script
js_test = _js_test
NpmPackagesInfo = _NpmPackagesInfo
npm_binary = _npm_binary
npm_packages = _npm_packages
ts_library = _ts_library
web_bundle = _web_bundle
