# Floci (quenchworks "full" mode) run as a plain Docker container on the real
# Docker host (192.168.1.98), NOT in Kubernetes. Full mode needs a real
# /var/run/docker.sock to drive the 10 Docker-backed AWS services (Lambda, RDS,
# ElastiCache, MSK, ECS, EKS, OpenSearch, ECR, DocumentDB, Neptune); Talos nodes
# run containerd only and have no such socket, so the Helm chart's full mode
# cannot work in-cluster (see envs/dev/kube-orchestrations/floci.yaml history).
# This is exactly the chart's own documented fallback: "run Floci on a Docker
# host outside Kubernetes."
#
# SECURITY: this mounts the HOST's real Docker socket read-write into the
# container. Anything able to reach floci's API can drive this entire host's
# Docker daemon - same trust level as root on 192.168.1.98. That host already
# runs the shared Traefik edge proxy, so treat it accordingly.

data "docker_network" "proxy" {
  name = var.network_name
}

resource "docker_volume" "floci_data" {
  name = "floci-data"
}

resource "docker_image" "floci_full" {
  name         = "ghcr.io/quenchworks/images/floci-full@${var.image_digest}"
  keep_locally = true
}

resource "docker_container" "floci" {
  name  = "floci"
  image = docker_image.floci_full.image_id

  restart = "unless-stopped"

  networks_advanced {
    name = data.docker_network.proxy.name
  }

  # Direct access for AWS SDK clients (e.g. --endpoint-url=http://192.168.1.98:4566),
  # in addition to the Traefik-routed https://floci.localdev.me below.
  ports {
    internal = 4566
    external = 4566
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    # read-only intentionally omitted: floci-full must create/start/stop
    # sibling containers through this socket for the Docker-backed services.
  }

  volumes {
    volume_name    = docker_volume.floci_data.name
    container_path = "/data"
  }

  env = [
    "FLOCI_PORT=4566",
    "FLOCI_DEFAULT_REGION=${var.default_region}",
    "FLOCI_DEFAULT_ACCOUNT_ID=000000000000",
    "LOCALSTACK_PARITY=true",
    "FLOCI_STORAGE_MODE=persistent",
    "FLOCI_STORAGE_PERSISTENT_PATH=/data",
  ]

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.floci.rule"
    value = "Host(`${var.host}`)"
  }

  labels {
    label = "traefik.http.routers.floci.entrypoints"
    value = "websecure"
  }

  labels {
    label = "traefik.http.routers.floci.tls"
    value = "true"
  }

  # Without this, Traefik's eks catch-all (HostRegexp(`.*.localdev.me`)) ties
  # with this exact-Host router on rule length and can win by default priority
  # - the exact same bug fixed for the dashboard/nas routers. Set explicitly.
  labels {
    label = "traefik.http.routers.floci.priority"
    value = "100"
  }

  labels {
    label = "traefik.http.services.floci.loadbalancer.server.port"
    value = "4566"
  }
}
