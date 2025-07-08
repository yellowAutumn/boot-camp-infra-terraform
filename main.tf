# Configure the Google Cloud Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# =============================
# Variables
# =============================

variable "qa_region" {
  description = "Region for QA Cloud Deploy target"
  type        = string
  default     = "us-west1"
}

variable "prod_region" {
  description = "Region for Prod Cloud Deploy target"
  type        = string
  default     = "us-east1"
}

# Enable required APIs
resource "google_project_service" "cloud_run_api" {
  service = "run.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "iam_api" {
  service = "iam.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

# =============================
# GCP Cloud Deploy for Cloud Run Promotion (Dev, QA, Prod)
# =============================

# Enable Cloud Deploy API
resource "google_project_service" "clouddeploy_api" {
  service = "clouddeploy.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

# Cloud Deploy service account (used by Cloud Deploy to deploy to Cloud Run)
resource "google_service_account" "clouddeploy_sa" {
  account_id   = "clouddeploy-sa"
  display_name = "Cloud Deploy Service Account"
  description  = "Service account for GCP Cloud Deploy to manage Cloud Run releases"
  depends_on   = [google_project_service.iam_api]
}

# Grant Cloud Deploy SA permission to deploy to Cloud Run and impersonate other SAs
resource "google_project_iam_member" "clouddeploy_sa_roles" {
  for_each = toset([
    "roles/run.admin",
    "roles/iam.serviceAccountUser"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.clouddeploy_sa.email}"
  depends_on = [google_service_account.clouddeploy_sa]
}

# Cloud Deploy targets for each environment (fixed for Cloud Run)
resource "google_clouddeploy_target" "dev" {
  name     = "dev1"
  project  = var.project_id
  location = var.region
  require_approval = false
  execution_configs {
    usages = ["RENDER", "DEPLOY"]
    worker_pool = null
    artifact_storage = null
  }
   run {
    location = "projects/${var.project_id}/locations/${var.region}"
  }
  depends_on = [google_project_service.clouddeploy_api]
}

resource "google_clouddeploy_target" "qa" {
  name     = "qa1"
  project  = var.project_id
  location = var.region

  run {
   // location = "projects/${var.project_id}/locations/${var.qa_region}"
      location = "projects/${var.project_id}/locations/${var.qa_region}"

  }
  
  execution_configs {
    usages = ["RENDER", "DEPLOY"]
    worker_pool = null
    artifact_storage = null
  }
  depends_on = [google_project_service.clouddeploy_api]
}

resource "google_clouddeploy_target" "prod" {
  name     = "prod1"
  project  = var.project_id
  location = var.region
  require_approval = true
  
   run {
    location = "projects/${var.project_id}/locations/${var.prod_region}"
  }
  execution_configs {
    usages = ["RENDER", "DEPLOY"]
    worker_pool = null
    artifact_storage = null
  }
  depends_on = [google_project_service.clouddeploy_api]
}

# Cloud Deploy pipeline
resource "google_clouddeploy_delivery_pipeline" "cloudrun_pipeline" {
  name     = "cloudrun-pipeline"
  project  = var.project_id
  location = var.region

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.dev.name
      profiles  = []
    }
    stages {
      target_id = google_clouddeploy_target.qa.name
      profiles  = []
    }
    stages {
      target_id = google_clouddeploy_target.prod.name
      profiles  = []
    }
  }
  depends_on = [
    google_clouddeploy_target.dev,
    google_clouddeploy_target.qa,
    google_clouddeploy_target.prod
  ]
}

# Create a service account for Cloud Run
resource "google_service_account" "cloud_run_sa" {
  account_id   = "${var.service_name}-sa"
  display_name = "Cloud Run Service Account"
  description  = "Service account for Cloud Run service"

  depends_on = [google_project_service.iam_api]
}

# IAM roles for the Cloud Run service account
resource "google_project_iam_member" "cloud_run_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent",
    "roles/cloudsql.client"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"

  depends_on = [google_service_account.cloud_run_sa]
}

# Create a deployment service account for CI/CD
resource "google_service_account" "deployment_sa" {
  account_id   = "${var.service_name}-deploy-sa"
  display_name = "Deployment Service Account"
  description  = "Service account for deploying Cloud Run services"

  depends_on = [google_project_service.iam_api]
}

# IAM roles for the deployment service account
resource "google_project_iam_member" "deployment_sa_roles" {
  for_each = toset([
    "roles/run.developer",
    "roles/iam.serviceAccountUser",
    "roles/storage.objectViewer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployment_sa.email}"

  depends_on = [google_service_account.deployment_sa]
}

# Create a monitoring service account
resource "google_service_account" "monitoring_sa" {
  account_id   = "${var.service_name}-monitor-sa"
  display_name = "Monitoring Service Account"
  description  = "Service account for monitoring and alerting"

  depends_on = [google_project_service.iam_api]
}

# IAM roles for the monitoring service account
resource "google_project_iam_member" "monitoring_sa_roles" {
  for_each = toset([
    "roles/monitoring.editor",
    "roles/logging.viewer",
    "roles/cloudtrace.user"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"

  depends_on = [google_service_account.monitoring_sa]
}

# Custom IAM role for Cloud Run operations
resource "google_project_iam_custom_role" "cloud_run_operator" {
  role_id     = "${replace(var.service_name, "-", "_")}_operator"
  title       = "${var.service_name} Cloud Run Operator"
  description = "Custom role for Cloud Run operations"
  
  permissions = [
    "run.services.get",
    "run.services.list",
    "run.services.update",
    "run.revisions.get",
    "run.revisions.list",
    "run.configurations.get",
    "run.configurations.list"
  ]
}

# Assign custom role to deployment service account
resource "google_project_iam_member" "deployment_custom_role" {
  project = var.project_id
  role    = google_project_iam_custom_role.cloud_run_operator.name
  member  = "serviceAccount:${google_service_account.deployment_sa.email}"

  depends_on = [
    google_service_account.deployment_sa,
    google_project_iam_custom_role.cloud_run_operator
  ]
}

# Cloud Run service
resource "google_cloud_run_v2_service" "main" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloud_run_sa.email
    
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.container_image
      
      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      
      env {
        name  = "REGION"
        value = var.region
      }
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_project_service.cloud_run_api,
    google_service_account.cloud_run_sa
  ]
}

# IAM policy to allow public access
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_storage_bucket" "cloud_deploy" {
  name     = "cloud-deploy-${var.project_id}"
  location = var.region
  force_destroy = true
}

resource "google_storage_bucket_object" "cloudrun_manifest" {
  name   = "manifest/cloudrun-pipeline-manifest.yaml"
  bucket = google_storage_bucket.cloud_deploy.name
  source = "${path.module}/cloudrun-pipeline-manifest.yaml"
}

resource "google_storage_bucket_object" "cloudrun_manifest_qa" {
  name   = "manifest/cloudrun-pipeline-manifest-qa.yaml"
  bucket = google_storage_bucket.cloud_deploy.name
  source = "${path.module}/cloudrun-pipeline-manifest-qa.yaml"
}

resource "google_storage_bucket_object" "bootcamp4_folder" {
  name   = "bootcamp-4/"
  bucket = google_storage_bucket.cloud_deploy.name
  content = " " # Use a single space to satisfy the provider
}

resource "google_storage_bucket_object" "skaffold_config" {
  name   = "manifest/skaffold.yaml"
  bucket = google_storage_bucket.cloud_deploy.name
  source = "${path.module}/manifest/skaffold.yaml"
}

output "cloud_deploy_bucket_url" {
  value = "gs://${google_storage_bucket.cloud_deploy.name}"
  description = "Cloud Deploy bucket URL"
}

output "cloudrun_manifest_url" {
  value = "gs://${google_storage_bucket.cloud_deploy.name}/${google_storage_bucket_object.cloudrun_manifest.name}"
  description = "Cloud Run manifest object URL"
}

