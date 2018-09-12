# Dockerized Node server in TypeScript

This directory contains a Docker image with a Node server built from TypeScript with Bazel.

A few things worth noting:

- `tsconfig.json` must have `allowSyntheticDefaultImports` set to `false`
- We generate source maps and run `node -r source-map-support/register` so error stack traces
  match the TypeScript source.
- We don't use any TypeScript aliases, because they will remain as such and confuse Node. This
  could be fixed by re-introducing preprocessing which was removed in [d81c2e3](https://github.com/zenclabs/bazel-javascript/commit/d81c2e3f130fe09348952963d58fe560a416e5da).
- We use a symlinked directory to ensure `node_modules` is available to Node.
- `WORKSPACE` needs to be edited to include the remote, not local version of `bazel_javascript`.

## Deploying to Kubernetes

You can use [skaffold](https://github.com/GoogleContainerTools/skaffold) to
deploy this app to kubernetes. To run skaffold, you will need
[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and
[helm](https://helm.sh/) installed. For a simple local development
environment you can install docker and [enable
kubernetes](https://docs.docker.com/docker-for-mac/#kubernetes).

To get at the app you can run `kubectl port-forward service/my-service 3000:3000`
