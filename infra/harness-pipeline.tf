# Harness pipelines and their triggers, from envs/nonprod.yaml (harness.pipelines and
# harness.triggers). Rules and safeguards: ../modules/harness-pipeline/README.md

module "harness_pipeline" {
  source = "../modules/harness-pipeline"

  org_id      = local.harness_org
  project_id  = local.harness_project
  repo_root   = "${path.module}/.."
  default_git = local.configs.harness.git
  pipelines   = local.configs.harness.pipelines
  triggers    = local.configs.harness.triggers
}

# The pipelines used to be declared here.
moved {
  from = harness_platform_pipeline.this
  to   = module.harness_pipeline.harness_platform_pipeline.this
}

output "harness_webhook_urls" {
  value = module.harness_pipeline.webhook_urls
}
