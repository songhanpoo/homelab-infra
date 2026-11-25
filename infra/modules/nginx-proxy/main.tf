
# Pull the nginx-proxy-manager image
resource "docker_image" "nginx_proxy_manager" {
  name         = "jc21/nginx-proxy-manager:2.12.3"
  keep_locally = false
}

# Create persistent volumes for data and letsencrypt
resource "docker_volume" "data" {
  name   = "${var.service_name}-data"
  driver = "local"
}

resource "docker_volume" "letsencrypt" {
  name   = "${var.service_name}-letsencrypt"
  driver = "local"
}

# Create the nginx-proxy-manager container
resource "docker_container" "nginx_proxy_manager" {
  name              = var.service_name
  image             = docker_image.nginx_proxy_manager.image_id
  must_run          = false
  publish_all_ports = false
  restart           = "always"


  # Port mappings
  ports {
    internal = 80
    external = var.http_port
  }

  ports {
    internal = 443
    external = var.https_port
  }

  ports {
    internal = 81
    external = var.admin_port
  }

  # Environment variables
  env = [
    "TZ=${var.timezone}",
    "INITIAL_ADMIN_EMAIL=songhanpoo@gmail.com",
    "INITIAL_ADMIN_PASSWORD=changeme1234",
  ]

  # Volume mounts
  mounts {
    type   = "volume"
    source = docker_volume.data.name
    target = "/data"
  }

  mounts {
    type   = "volume"
    source = docker_volume.letsencrypt.name
    target = "/etc/letsencrypt"
  }

  # Health check (optional)
  healthcheck {
    test     = ["CMD", "/usr/bin/check-health"]
    interval = "10s"
    timeout  = "3s"
    retries  = 3
  }

  depends_on = [docker_image.nginx_proxy_manager]
}
