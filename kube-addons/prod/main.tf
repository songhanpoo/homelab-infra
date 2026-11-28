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
    # Traefik (envs/platform/traefik.yaml) forwards to this port. Without pinning it,
    # a reinstall gets a random NodePort and every route returns 502.
    {
      name  = "controller.service.nodePorts.http"
      value = tostring(local.config.ingress_nginx_internal.http_node_port)
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

# CoreDNS settings (files/Corefile). Talos creates this ConfigMap; Terraform manages only the
# Corefile in it. The local.proxy block forwards to Pi-hole and answers IPv6 (AAAA) lookups with
# "no address": Pi-hole can reply NXDOMAIN, which makes Alpine builds fail with ENOTFOUND.
#
# "force" takes the field over from whoever set it last (kubectl edit, or Talos after a Kubernetes
# upgrade). Make later changes in files/Corefile: manual edits are overwritten by the next apply.
resource "kubernetes_config_map_v1_data" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  data = {
    Corefile = file("${path.module}/files/Corefile")
  }
  field_manager = "terraform-coredns"
  force         = true

  # Destroying this removes the Corefile and breaks DNS for the whole cluster. To destroy the prod
  # tier, or to stop managing CoreDNS, first make Terraform forget it (the cluster keeps the file):
  #   terraform state rm kubernetes_config_map_v1_data.coredns
  lifecycle {
    prevent_destroy = true
  }
}
