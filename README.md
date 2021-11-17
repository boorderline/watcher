# watcher

[![CI](https://github.com/boorderline/watcher/actions/workflows/CI.yml/badge.svg)](https://github.com/boorderline/watcher/actions/workflows/CI.yml)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/boord)](https://artifacthub.io/packages/search?repo=boord)

Helm-based continuous delivery tool.

## Description

Watcher checks Helm repositories for new versions of configured Charts based on a strategy. If a new version is available, then it will try to deploy it inside your cluster automatically.

## Installation

### From source

Please make sure you have [installed Crystal](https://crystal-lang.org/install/) and friends on your machine. Once you have all the tooling in place, let's start building the application:

```
shards build --release --no-debug --static
```

This will build the application in "production" mode; it might take a few seconds to spit out an executable. Once done, the application will be available inside the `./bin` directory.

**NOTE:** You will NOT be able to build a static executable under macOS; you will need to remove the `--static` option.

### Using Docker

```
docker pull boord/watcher
docker run
```

**NOTE:** You can also check the provided Docker Compose file for an example of how to run the application.

### Via Helm

```
helm repo add boord https://charts.boord.io
helm install watcher boord/watcher
```

## Configuration

```yaml
version: "1"
name: Grafana

source:
  repository: https://grafana.github.io/helm-charts
  chart: grafana
  strategy: LatestCreatedStable

target:
  name: grafana
  namespace: monitoring
  create_namespace: true
  values:
    service:
      type: LoadBalancer

    persistence:
      enabled: true
      size: 20Gi
```

## Development environment

The development environment has the following requirements:

- [minikibe](https://minikube.sigs.k8s.io/docs/) or an alternative, the Kubernetes version distributed with Docker seems to work fine.
- [Helm](https://helm.sh/docs/intro/install/) (optional)
- [Helm ChartMuseum plugin](https://github.com/chartmuseum/helm-push) (optional)

```
docker-compose up -d --build
```

Running the command above will build, and start `watcher` alongside a `chartmuseum` instance. To quickly inspect the logs for `watcher`, just run the following command:

```
docker logs -f watcher
```

At this point, `chartmuseum` is available on http://localhost:8080 and the authentication/authorization features are entirely disabled. You can use your local `helm` CLI tool to interact with it. If you have installed the [ChartMuseum Push plugin](https://github.com/chartmuseum/helm-push), you can start uploading Helm Charts into this instance.

You can remove the entire development environment with the following command:

```
docker-compose down
```

## Contributing

1. Fork it (<https://github.com/boorderline/watcher/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Tudor Marghidanu](https://github.com/marghidanu) - creator and maintainer
