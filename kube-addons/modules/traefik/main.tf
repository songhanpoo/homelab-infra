resource "docker_network" "proxy" {
  name = "proxy"
}

resource "docker_image" "traefik" {
  name         = "traefik:${var.traefik_version}"
  keep_locally = true
}

resource "docker_container" "traefik" {
  name  = "traefik"
  image = docker_image.traefik.image_id

  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.proxy.name
  }

  ports {
    internal = 80
    external = 80
  }

  ports {
    internal = 443
    external = 443
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  volumes {
    host_path      = "/home/songhanpoo/traefik/certs"
    container_path = "/certs"
    read_only      = true
  }

  volumes {
    host_path      = "/home/songhanpoo/traefik/dynamic"
    container_path = "/dynamic"
    read_only      = true
  }

  command = [
    "--entrypoints.web.address=:80",
    "--entrypoints.web.http.redirections.entrypoint.to=websecure",
    "--entrypoints.web.http.redirections.entrypoint.scheme=https",
    "--entrypoints.web.http.redirections.entrypoint.permanent=true",
    "--entrypoints.websecure.address=:443",
    "--entrypoints.websecure.http.tls=true",

    "--providers.file.filename=/dynamic/tls.yaml",

    "--providers.docker=true",
    "--providers.docker.exposedbydefault=false",
    "--providers.docker.network=proxy",

    "--api.dashboard=true",
    "--api.insecure=false",

    "--log.level=INFO",
    "--accesslog=true",
    # "--metrics.prometheus=true"
  ]

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_image" "whoami" {
  name         = "traefik/whoami"
  keep_locally = true
}

resource "docker_container" "whoami" {
  name  = "whoami"
  image = docker_image.whoami.image_id

  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.proxy.name
  }
  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.whoami.rule"
    value = "Host(`whoami.local.me`)"
  }

  labels {
    label = "traefik.http.routers.whoami.entrypoints"
    value = "websecure"
  }

  labels {
    label = "traefik.http.routers.whoami.tls"
    value = "true"
  }
}
