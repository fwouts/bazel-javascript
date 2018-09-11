# my-service Helm Chart

[Helm](https://helm.sh/) is "The package manager for kubernetes". It allows
you to define a bundle of [kubernetes
objects](https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/)
with templated variables that a downstream user can override. Helm calls the
bundles "Helm Charts" and they can be used as a dependency by other Helm Charts.

Many Helm Charts are already available, you can see some of the official ones
[here](https://github.com/helm/charts/tree/master/stable). Using a published
helm chart enables you to add something to kubernetes with minimal work.

To use helm you need to [initialize helm and install tiller
into your kubernetes cluster](https://docs.helm.sh/using_helm/#quickstart).
Helm's Tiller Server manages the Helm Charts that are deployed in your
cluster.

The chart in my-service is a default chart that was created using the helm
cli: `helm create my-service`