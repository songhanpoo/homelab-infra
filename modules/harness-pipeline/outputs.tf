output "pipeline_ids" {
  value = sort(keys(harness_platform_pipeline.this))
}

output "webhook_urls" {
  description = "Webhook URL per github_push trigger (Harness registers it in GitHub if the connector allows)."
  value       = { for id, t in harness_platform_triggers.this : id => t.webhook_url if var.triggers[id].type == "github_push" }
}
