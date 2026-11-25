# ThinkRead Helm Chart

This directory contains the Helm chart for deploying the ThinkRead application on a Kubernetes cluster.

## Overview

The ThinkRead Helm chart allows you to easily deploy the ThinkRead EPUB library and reader application. It provides a simple way to manage the deployment, service, and ingress resources required to run the application.

## Prerequisites

- Kubernetes cluster
- Helm 3.x installed

## Installation

To install the ThinkRead chart, use the following command:

```bash
helm install thinkread ./thinkread
```

This command will deploy the ThinkRead application using the default configuration values defined in `values.yaml`.

## Configuration

You can customize the deployment by modifying the `values.yaml` file. Here are some of the configurable parameters:

- `image.repository`: The Docker image repository for the ThinkRead application.
- `image.tag`: The specific version of the Docker image to use.
- `service.type`: The type of service to create (e.g., `ClusterIP`, `NodePort`, `LoadBalancer`).
- `service.port`: The port on which the service will be exposed.

## Accessing the Application

Once the application is deployed, you can access it using the service created by the Helm chart. If you have configured an ingress, you can access it via the specified hostname.

## Uninstalling the Chart

To uninstall the ThinkRead chart, run the following command:

```bash
helm uninstall thinkread
```

This will remove all resources associated with the ThinkRead application.

## License

This Helm chart is licensed under the MIT License.