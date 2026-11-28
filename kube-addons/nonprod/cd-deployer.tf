# The account the k8s-deploy pipeline uses, limited to the application namespaces listed in
# deploy/services/*.yaml. Setup and risks: deploy/README.md.

locals {
  cd_services = {
    for f in fileset("${path.module}/../../deploy/services", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/../../deploy/services/${f}"))
  }
  cd_namespaces = toset([for s in local.cd_services : s.namespace])

  # The cluster address written into the pipeline's kubeconfig.
  cd_api_server = "https://192.168.1.130:6443"
}

# "restricted" stops the deploy account (or a bad chart) from starting privileged pods.
resource "kubernetes_namespace_v1" "cd_app" {
  for_each = local.cd_namespaces
  metadata {
    name = each.value
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# The account lives in its own namespace, where no pipeline job pod runs: a pod could otherwise
# simply ask to run as it.
resource "kubernetes_namespace_v1" "cd_deployer" {
  metadata {
    name = "cd-deployer"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

resource "kubernetes_service_account_v1" "cd_deployer" {
  metadata {
    name      = "cd-deployer"
    namespace = kubernetes_namespace_v1.cd_deployer.metadata[0].name
  }
  automount_service_account_token = false
}

# A long-lived token. To rotate it: apply with -replace on this resource.
resource "kubernetes_secret_v1" "cd_deployer_token" {
  metadata {
    name      = "cd-deployer-token"
    namespace = kubernetes_namespace_v1.cd_deployer.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.cd_deployer.metadata[0].name
    }
  }
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

# Only what Helm needs for the web-service chart. "secrets" is required because Helm keeps its
# release records there; it also lets this account read the application's own secrets.
resource "kubernetes_role_v1" "cd_deployer" {
  for_each = local.cd_namespaces
  metadata {
    name      = "cd-deployer"
    namespace = kubernetes_namespace_v1.cd_app[each.value].metadata[0].name
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["services", "secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "cd_deployer" {
  for_each = local.cd_namespaces
  metadata {
    name      = "cd-deployer"
    namespace = kubernetes_namespace_v1.cd_app[each.value].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.cd_deployer[each.value].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.cd_deployer.metadata[0].name
    namespace = kubernetes_namespace_v1.cd_deployer.metadata[0].name
  }
}

locals {
  cd_kubeconfig = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = "talos"
      cluster = {
        server                       = local.cd_api_server
        "certificate-authority-data" = base64encode(kubernetes_secret_v1.cd_deployer_token.data["ca.crt"])
      }
    }]
    users = [{
      name = "cd-deployer"
      user = { token = kubernetes_secret_v1.cd_deployer_token.data["token"] }
    }]
    contexts          = [{ name = "cd-deployer", context = { cluster = "talos", user = "cd-deployer" } }]
    "current-context" = "cd-deployer"
  })
}

# Read by .harness/pipelines/cd.yaml. Anyone who can run or edit pipelines in the project can
# use this account.
resource "harness_platform_secret_text" "cd_kubeconfig_b64" {
  identifier  = "cd_kubeconfig_b64"
  name        = "cd_kubeconfig_b64"
  description = "Kubeconfig of the limited cd-deployer account, base64. Managed by Terraform (kube-addons/nonprod)."
  org_id      = "default"
  project_id  = "visabulletin"

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = base64encode(local.cd_kubeconfig)
}
