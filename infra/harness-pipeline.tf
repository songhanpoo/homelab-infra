# Onboards the pipelines in envs/nonprod.yaml (harness.pipelines) as Remote pipelines: Harness reads
# the YAML from Git. Git is the source of truth; Terraform never sends YAML.

locals {
  harness_git       = local.configs.harness.git
  harness_pipelines = { for id, p in local.configs.harness.pipelines : id => p if p.enabled }
}

resource "harness_platform_pipeline" "this" {
  for_each = local.harness_pipelines

  identifier = each.key
  name       = each.value.name
  org_id     = local.harness_org
  project_id = local.harness_project

  import_from_git = true
  git_import_info {
    connector_ref = local.harness_git.connector_ref
    repo_name     = local.harness_git.repo_name
    branch_name   = local.harness_git.branch
    file_path     = each.value.file_path
  }
  pipeline_import_request {
    pipeline_name        = each.value.name
    pipeline_description = each.value.description
  }

  lifecycle {
    # Onboard only. An update would send the YAML held in state back to Harness, which could
    # overwrite newer content in Git. Changing the settings above later has no effect.
    ignore_changes = all

    # "iacm" is the pipeline that applies infra, so Terraform must not delete it. To stop managing
    # one:  terraform state rm 'harness_platform_pipeline.this["<identifier>"]'
    # and then set it to enabled: false.
    prevent_destroy = true

    # Checks the working copy, not the Git branch: it catches a wrong path or identifier early.
    precondition {
      condition = try(
        yamldecode(file("${path.module}/../${each.value.file_path}")).pipeline.identifier == each.key &&
        yamldecode(file("${path.module}/../${each.value.file_path}")).pipeline.orgIdentifier == local.harness_org &&
        yamldecode(file("${path.module}/../${each.value.file_path}")).pipeline.projectIdentifier == local.harness_project,
        false
      )
      error_message = "${each.value.file_path} must exist and have identifier \"${each.key}\" and the org and project from envs/nonprod.yaml."
    }
  }
}
