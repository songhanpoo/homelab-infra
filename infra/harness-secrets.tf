# Cluster credentials kept as Harness secrets, base64 on one line (the pipeline decodes them).
# After a rebuild, an infra apply updates them. The values are also in Terraform state.
# Edit them only through Terraform: don't count on a plan noticing a value changed in the UI.
#
# prevent_destroy: every run of the iacm pipeline reads kubeconfig_b64, including infra runs, so
# deleting it would stop the pipeline from rebuilding the cluster. It also blocks "destroy" for
# the whole infra root. To destroy infra and keep the secrets, first run, in infra/:
#   terraform state rm harness_platform_secret_text.kubeconfig_b64 harness_platform_secret_text.talosconfig_b64
# and remove the import block below until the secret is to be managed again.

locals {
  harness_org     = local.configs.harness.org_id
  harness_project = local.configs.harness.project_id
}

# kubeconfig_b64 was first created by hand: take it over instead of creating it.
import {
  to = harness_platform_secret_text.kubeconfig_b64
  id = "default/visabulletin/kubeconfig_b64"
}

resource "harness_platform_secret_text" "kubeconfig_b64" {
  identifier  = "kubeconfig_b64"
  name        = "kubeconfig_b64"
  description = "Cluster kubeconfig, base64. Managed by Terraform (infra/)."
  org_id      = local.harness_org
  project_id  = local.harness_project

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = base64encode(module.talos.kubeconfig_raw)

  lifecycle {
    prevent_destroy = true
  }
}

# Full administrator access to the Talos nodes. No pipeline step reads it today.
resource "harness_platform_secret_text" "talosconfig_b64" {
  identifier  = "talosconfig_b64"
  name        = "talosconfig_b64"
  description = "Talos client config, base64: full admin of the nodes. Managed by Terraform (infra/)."
  org_id      = local.harness_org
  project_id  = local.harness_project

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = base64encode(module.talos.client_configuration.talos_config)

  lifecycle {
    prevent_destroy = true
  }
}
