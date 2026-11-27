module "traefik" {
  source          = "../../modules/traefik"
  traefik_version = local.config.traefik.version
  config_yaml     = file("${path.module}/envs/platform/traefik.yaml")
}

module "dns" {
  source  = "../../modules/pihole-dns"
  records = local.config.dns.records
}

resource "helm_release" "ingress-nginx-internal" {
  name = local.config.ingress_nginx_internal.name

  repository = local.config.ingress_nginx_internal.repository
  chart      = local.config.ingress_nginx_internal.chart
  namespace  = local.config.ingress_nginx_internal.namespace
  version    = local.config.ingress_nginx_internal.version
  wait       = false

  set = [
    {
      name  = "controller.ingressClassResource.name"
      value = local.config.ingress_nginx_internal.ingress_class_name
    },
    {
      name  = "controller.ingressClassResource.controllerValue"
      value = local.config.ingress_nginx_internal.controller_value
    },
    # Traefik terminates TLS and forwards X-Forwarded-Proto: https; without this nginx
    # overwrites it with http and Nexus advertises an http:// Docker token realm.
    {
      name  = "controller.config.use-forwarded-headers"
      value = "true"
    },
  ]
}

resource "helm_release" "csi-driver-nfs" {
  name = local.config.csi_driver_nfs.name

  repository      = local.config.csi_driver_nfs.repository
  chart           = local.config.csi_driver_nfs.chart
  namespace       = local.config.csi_driver_nfs.namespace
  version         = local.config.csi_driver_nfs.version
  wait            = false
  upgrade_install = false

}

module "storage_classes" {
  source          = "../../modules/storage-class"
  storage_classes = local.config.storage_classes
}

resource "kubernetes_namespace_v1" "kube-monitoring" {
  metadata {
    name = "kube-monitoring"
  }
}

resource "helm_release" "metrics_server" {
  name            = local.config.metrics_server.name
  repository      = local.config.metrics_server.repository
  chart           = local.config.metrics_server.chart
  version         = local.config.metrics_server.version
  namespace       = local.config.metrics_server.namespace
  upgrade_install = true
  wait            = false
  values = [
    yamlencode(local.config.metrics_server.values_yaml)
  ]
}
