locals {
  cfg = yamldecode(var.config_yaml).traefik

  # Auto-generate router labels by iterating over all routers in dev.yaml.
  # Each router's scalar attributes (rule, entrypoints, service, tls, middlewares…)
  # are emitted as:  traefik.http.routers.<name>.<attr> = <value>
  # Adding a new router to dev.yaml automatically produces all its labels here.
  router_labels = merge([
    for router_name, router_cfg in local.cfg.http.routers : {
      for attr_name, attr_value in router_cfg :
      "traefik.http.routers.${router_name}.${attr_name}" => tostring(attr_value)
    }
  ]...)

  # Auto-generate service labels by iterating over all services in dev.yaml.
  # Emits:  traefik.http.services.<name>.loadbalancer.server.url = <url>
  service_labels = {
    for svc_name, svc_cfg in local.cfg.http.services :
    "traefik.http.services.${svc_name}.loadbalancer.server.url" => svc_cfg.loadbalancer.server.url
  }

  labels = merge(
    { "traefik.enable" = tostring(local.cfg.enable) },
    local.router_labels,
    local.service_labels,
  )
}
