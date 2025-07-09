# Terraform variables configuration for Cloud Run with IAM
# This configuration will create:
# - Cloud Run service with the specified container
# - 3 service accounts: runtime, deployment, and monitoring
# - Custom IAM role for Cloud Run operations
# - Proper IAM bindings for all service accounts

# ====================================================
# REQUIRED: Update with your actual GCP project ID
# ====================================================
project_id = "pr-db-fn-1"

# ====================================================
# Infrastructure Configuration
# ====================================================
region = "us-central1"

# Service name (will be used to name all related resources)
# This creates:
# - Cloud Run service: "bootcamp-app"
# - Service accounts: "bootcamp-app-sa", "bootcamp-app-deploy-sa", "bootcamp-app-monitor-sa"
# - Custom role: "bootcamp_app_operator"
service_name = "temp-convertion"

# ====================================================
# Container Configuration
# ====================================================
# Container image to deploy (replace with your own image)
container_image = "gcr.io/pr-db-fn-1/temp-convert-webapp:latest"

# Port your container listens on
container_port = 5000

# Resource limits
cpu_limit = "1000m"      # 1 vCPU
memory_limit = "512Mi"   # 512 MB

# ====================================================
# Scaling Configuration
# ====================================================
# Scale to zero when no traffic (cost-effective)
min_instances = 0

# Maximum instances for traffic spikes
max_instances = 10
