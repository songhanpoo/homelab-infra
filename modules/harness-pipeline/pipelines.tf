# Remote pipelines: Harness reads the YAML from Git, which is the source of truth. Terraform only
# onboards them and never sends YAML.

locals {
  pipelines = {
    for id, p in var.pipelines : id => merge(p, {
      git     = p.git != null ? p.git : var.default_git
      in_repo = p.git == null
    })
  }
}

resource "harness_platform_pipeline" "this" {
  for_each = { for id, p in local.pipelines : id => p if p.enabled }

  identifier = each.key
  name       = each.value.name
  org_id     = var.org_id
  project_id = var.project_id

  import_from_git = true
  git_import_info {
    connector_ref = each.value.git.connector_ref
    repo_name     = each.value.git.repo_name
    branch_name   = each.value.git.branch
    file_path     = each.value.file_path
  }
  pipeline_import_request {
    pipeline_name        = each.value.name
    pipeline_description = each.value.description
  }

  lifecycle {
    # Onboard only. An update would send the YAML held in state back to Harness, which could
    # overwrite newer content in Git. Changing these settings later has no effect.
    ignore_changes = all

    # One of these pipelines applies this very configuration. To stop managing one:
    #   terraform state rm 'module.harness_pipeline.harness_platform_pipeline.this["<id>"]'
    # and then set it to enabled: false.
    prevent_destroy = true

    # For files in this repository, checks the working copy to catch mistakes early. Files in
    # other repositories can't be checked here.
    precondition {
      condition = !each.value.in_repo || try(
        yamldecode(file("${var.repo_root}/${each.value.file_path}")).pipeline.identifier == each.key &&
        yamldecode(file("${var.repo_root}/${each.value.file_path}")).pipeline.orgIdentifier == var.org_id &&
        yamldecode(file("${var.repo_root}/${each.value.file_path}")).pipeline.projectIdentifier == var.project_id,
        false
      )
      error_message = "${each.value.file_path} must exist and have identifier \"${each.key}\" and the configured org and project."
    }
  }
}
