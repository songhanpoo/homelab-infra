output "uscis_crawler_workflow_id" {
  value       = n8n_workflow.uscis_processing_time_crawler.id
  description = "The ID of the USCIS Crawler workflow"
}

output "uscis_crawler_workflow_name" {
  value       = n8n_workflow.uscis_processing_time_crawler.name
  description = "The name of the USCIS Crawler workflow"
}
