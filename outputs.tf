output "cloud_run_url" {
  description = "URL of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.main.uri
}

output "service_account_email" {
  description = "Email of the Cloud Run service account"
  value       = google_service_account.cloud_run_sa.email
}

output "deployment_service_account_email" {
  description = "Email of the deployment service account"
  value       = google_service_account.deployment_sa.email
}

output "monitoring_service_account_email" {
  description = "Email of the monitoring service account"
  value       = google_service_account.monitoring_sa.email
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.name
}

output "custom_role_name" {
  description = "Name of the custom Cloud Run operator role"
  value       = google_project_iam_custom_role.cloud_run_operator.name
}

output "service_accounts_summary" {
  description = "Summary of all created service accounts"
  value = {
    cloud_run_sa    = google_service_account.cloud_run_sa.email
    deployment_sa   = google_service_account.deployment_sa.email
    monitoring_sa   = google_service_account.monitoring_sa.email
  }
}

output "iam_roles_assigned" {
  description = "Summary of IAM roles assigned to service accounts"
  value = {
    cloud_run_sa = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter", 
      "roles/cloudtrace.agent",
      "roles/cloudsql.client"
    ]
    deployment_sa = [
      "roles/run.developer",
      "roles/iam.serviceAccountUser",
      "roles/storage.objectViewer",
      google_project_iam_custom_role.cloud_run_operator.name
    ]
    monitoring_sa = [
      "roles/monitoring.editor",
      "roles/logging.viewer",
      "roles/cloudtrace.user"
    ]
  }
}
