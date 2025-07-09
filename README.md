# Boot-camp-Infra-Terraform

This Terraform project deploys a Cloud Run container service on Google Cloud Platform.

## What This Creates

### Core Infrastructure
- **Cloud Run Service**: A scalable containerized application
- **API Enablement**: Required Google Cloud APIs

### IAM & Security
- **Cloud Run Service Account**: Runtime identity with logging, monitoring, tracing, and CloudSQL permissions
- **Deployment Service Account**: CI/CD identity with Cloud Run deployment permissions
- **Monitoring Service Account**: Dedicated identity for monitoring and alerting operations
- **Custom IAM Role**: Cloud Run operator role with specific permissions
- **Public Access**: IAM policy for public service invocation

## Prerequisites

1. Google Cloud Project with billing enabled
2. Terraform >= 1.0 installed
3. Google Cloud CLI authenticated
4. Required permissions: Cloud Run Admin, Service Account Admin, Project IAM Admin

## Quick Start

### 1. Configure Your Project

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your project ID:
```hcl
project_id = "your-actual-project-id"
```

### 2. Authenticate with Google Cloud

```powershell
# Authenticate with gcloud
gcloud auth login
gcloud auth application-default login

# Set your project
gcloud config set project your-actual-project-id
```

### 3. Deploy

```powershell
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 4. Access Your Application

After deployment, you'll get the Cloud Run URL in the output. You can access your containerized application at that URL.

## Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP Project ID | (required) |
| `region` | GCP region | `us-central1` |
| `service_name` | Cloud Run service name | `my-app` |
| `container_image` | Container image to deploy | `gcr.io/cloudrun/hello` |
| `container_port` | Container port | `8080` |
| `cpu_limit` | CPU limit | `1000m` |
| `memory_limit` | Memory limit | `512Mi` |
| `min_instances` | Minimum instances | `0` |
| `max_instances` | Maximum instances | `10` |

## IAM & Security Details

This Terraform configuration creates a comprehensive IAM setup with three specialized service accounts:

### Service Accounts Created

#### 1. Cloud Run Service Account (`{service_name}-sa`)
**Purpose**: Runtime identity for the Cloud Run service
**Permissions**:
- `roles/logging.logWriter` - Write application logs
- `roles/monitoring.metricWriter` - Send metrics to Cloud Monitoring  
- `roles/cloudtrace.agent` - Send trace data for performance monitoring
- `roles/cloudsql.client` - Connect to Cloud SQL databases

#### 2. Deployment Service Account (`{service_name}-deploy-sa`)
**Purpose**: CI/CD pipeline identity for deploying services
**Permissions**:
- `roles/run.developer` - Deploy and manage Cloud Run services
- `roles/iam.serviceAccountUser` - Use service accounts for deployments
- `roles/storage.objectViewer` - Access container images in Container Registry
- Custom `{service_name}_operator` role - Specific Cloud Run operations

#### 3. Monitoring Service Account (`{service_name}-monitor-sa`)
**Purpose**: Dedicated identity for monitoring and alerting systems
**Permissions**:
- `roles/monitoring.editor` - Manage monitoring resources
- `roles/logging.viewer` - Read logs for analysis
- `roles/cloudtrace.user` - Access trace data for debugging

### Custom IAM Role

A custom role `{service_name}_operator` is created with specific Cloud Run permissions:
- `run.services.get/list/update` - Manage Cloud Run services
- `run.revisions.get/list` - Access service revisions
- `run.configurations.get/list` - View service configurations

### Security Best Practices

✅ **Principle of Least Privilege**: Each service account has only the minimum required permissions  
✅ **Separation of Concerns**: Different accounts for runtime, deployment, and monitoring  
✅ **Custom Roles**: Specific permissions instead of broad predefined roles where possible  
✅ **No User Accounts**: All operations use service accounts for better security  

### Using Service Accounts

After deployment, you can use the service accounts for:

**For CI/CD Pipelines**:
```bash
# Use the deployment service account key
gcloud auth activate-service-account --key-file=deployment-sa-key.json
gcloud run deploy --image=gcr.io/your-project/your-app:latest
```

**For Monitoring Setup**:
```bash
# Use the monitoring service account for custom monitoring tools
export GOOGLE_APPLICATION_CREDENTIALS="monitoring-sa-key.json"
```

## Using Your Own Container

To deploy your own container, update the `container_image` variable:

```hcl
container_image = "gcr.io/your-project/your-app:latest"
container_port = 3000  # Your app's port
```

## Cleanup

To remove all resources:

```powershell
terraform destroy
```

## Troubleshooting

**Permission Denied**: Ensure your account has the required IAM roles and billing is enabled.

**API Not Enabled**: The Terraform will automatically enable required APIs, but you can manually enable them:
```bash
gcloud services enable run.googleapis.com
gcloud services enable iam.googleapis.com
```

**Container Won't Start**: Check that your container image exists and is accessible, and that it listens on the configured port.