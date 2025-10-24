# NIST-Compliant Terraform Guidance for LocalStack

This guidance helps AI coding assistants generate NIST 800-53 compliant Terraform infrastructure code for LocalStack environments. While LocalStack simulates AWS services locally, we maintain the same security patterns that would be used in production environments.

## Important: LocalStack Free Tier Limitations

**LocalStack Community Edition** (free) includes basic AWS services like S3, IAM, Lambda, SQS, and SNS.

**LocalStack Pro** (paid) is required for: RDS, ECS, EKS, and other advanced services.

This demo uses **free-tier services** (S3) and runs PostgreSQL as a Kubernetes StatefulSet instead of using RDS.

## Purpose

Generate Terraform code that:
- Implements NIST 800-53 security controls from the start
- Uses secure baselines for all resources
- Includes compliance annotations and mappings
- Produces documentation suitable for ATO artifacts
- Works with LocalStack Community Edition (free)

## Terraform Provider Configuration

### LocalStack Provider Setup

When generating provider configuration for LocalStack:

```hcl
# File: provider.tf
# NIST 800-53: CM-2 (Baseline Configuration)
# Infrastructure provisioning configuration for LocalStack

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"  # LocalStack dummy credentials
  secret_key                  = "test"  # LocalStack dummy credentials
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localhost:4566"
    iam            = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    kms            = "http://localhost:4566"
  }

  default_tags {
    tags = {
      Environment        = "demo"
      ManagedBy         = "terraform"
      ComplianceFramework = "NIST-800-53"
      Project           = "atlas-ato-accelerator"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-atlas-demo"
}
```

## S3 Bucket Patterns

### Controls Addressed
- **SC-13**: Cryptographic Protection
- **SC-28**: Protection of Information at Rest  
- **SC-28(1)**: Cryptographic Protection (encryption at rest)
- **AU-2**: Audit Events
- **AU-9**: Protection of Audit Information
- **CP-9**: Information System Backup
- **CP-9(1)**: Testing for Reliability/Integrity
- **AC-6**: Least Privilege Access

### Compliant S3 Bucket

```hcl
# File: s3.tf
# NIST 800-53: SC-28, SC-28(1) - Protection of Information at Rest
# Compliance Level: Moderate Impact
# SSP Section Reference: 10.3.1 Data Encryption

resource "aws_s3_bucket" "app_storage" {
  bucket = var.bucket_name
  
  tags = {
    Name                       = var.bucket_name
    "compliance:nist-controls" = "SC-28,SC-28(1),AU-2,AU-9,CP-9,AC-6"
    "compliance:impact-level"  = "moderate"
    "ato:criticality"          = "high"
    "ato:data-classification"  = "sensitive"
  }
}

# NIST 800-53: SC-28(1) - Cryptographic Protection
resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"  # LocalStack free tier supports AES256
    }
  }
}

# NIST 800-53: CP-9 - Information System Backup
resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# NIST 800-53: AU-2, AU-9 - Audit Events and Protection
resource "aws_s3_bucket_logging" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}

# Separate bucket for logs
resource "aws_s3_bucket" "logs" {
  bucket = "${var.bucket_name}-logs"
  
  tags = {
    Name                       = "${var.bucket_name}-logs"
    "compliance:nist-controls" = "AU-2,AU-9"
    Purpose                    = "Access Logs"
  }
}

# NIST 800-53: AC-6 - Least Privilege
resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## PostgreSQL Database Patterns (Kubernetes)

Since RDS requires LocalStack Pro, we deploy PostgreSQL as a Kubernetes StatefulSet with NIST-compliant configurations.

### Controls Addressed
- **SC-28**: Protection of Information at Rest  
- **AU-2**: Audit Events
- **CP-9**: Information System Backup (via persistent volumes)
- **IA-5**: Authenticator Management
- **SC-7**: Boundary Protection

### Compliant PostgreSQL StatefulSet

```hcl
# File: k8s-postgres.tf
# NIST 800-53: SC-28, CP-9 - Database with Persistent Storage

resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name = "postgres"
    labels = {
      app                         = "postgres"
      "compliance:nist-controls"  = "SC-28,CP-9,IA-5,SC-7"
    }
  }

  spec {
    service_name = "postgres"
    replicas     = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        # NIST 800-53: SC-7 - Security Context
        security_context {
          run_as_non_root = true
          run_as_user     = 999  # postgres user
          fs_group        = 999
        }

        container {
          name  = "postgres"
          image = "postgres:15-alpine"

          # NIST 800-53: IA-5 - Authenticator Management
          env {
            name  = "POSTGRES_DB"
            value = var.db_name
          }
          
          env {
            name  = "POSTGRES_USER"
            value = var.db_username
          }
          
          env {
            name  = "POSTGRES_PASSWORD"
            value = var.db_password
            # Note: In production, use Kubernetes secrets
          }

          port {
            container_port = 5432
            name          = "postgresql"
          }

          # NIST 800-53: CP-9 - Persistent Storage
          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          # NIST 800-53: SC-7 - Container Security
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false
          }
        }
      }
    }

    # NIST 800-53: CP-9 - Persistent Volume Claim
    volume_claim_template {
      metadata {
        name = "postgres-data"
      }
      
      spec {
        access_modes = ["ReadWriteOnce"]
        
        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }
}

# Service for database access
resource "kubernetes_service" "postgres" {
  metadata {
    name = "postgres"
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }

    cluster_ip = "None"  # Headless service for StatefulSet
  }
}
```

## RDS Database Patterns (Reference Only - Requires LocalStack Pro)

**Note:** The patterns below are for reference and production use. LocalStack Community Edition does not support RDS. For the demo, use the PostgreSQL StatefulSet pattern above.

### Controls Addressed
- **SC-13**: Cryptographic Protection
- **SC-28**: Protection of Information at Rest  
- **SC-28(1)**: Cryptographic Protection (encryption at rest)
- **AU-2**: Audit Events
- **AU-9**: Protection of Audit Information
- **CP-9**: Information System Backup
- **CP-9(1)**: Testing for Reliability/Integrity
- **IA-5**: Authenticator Management
- **SI-7**: Software, Firmware, and Information Integrity

### Compliant RDS Instance

```hcl
# File: rds.tf
# NIST 800-53: SC-28, SC-28(1) - Protection of Information at Rest
# Compliance Level: Moderate Impact
# SSP Section Reference: 10.3.1 Data Encryption

# Note: LocalStack has limited encryption support, but we maintain
# production patterns for consistency

resource "aws_db_instance" "app_database" {
  identifier           = var.db_identifier
  engine              = "postgres"
  engine_version      = "14.7"
  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  storage_type        = "gp2"
  
  # NIST 800-53: SC-28(1) - Cryptographic Protection
  # Note: LocalStack may not fully support encryption, but we specify it
  storage_encrypted   = true
  kms_key_id         = aws_kms_key.database.arn
  
  # NIST 800-53: IA-5 - Authenticator Management
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password  # In production, use AWS Secrets Manager
  
  # NIST 800-53: CP-9 - Information System Backup
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  # NIST 800-53: AU-2, AU-9 - Audit Events and Protection
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  # NIST 800-53: SC-7 - Boundary Protection
  publicly_accessible = false
  vpc_security_group_ids = [aws_security_group.database.id]
  
  # NIST 800-53: SI-7 - Software, Firmware, and Information Integrity
  auto_minor_version_upgrade = true
  
  skip_final_snapshot = true  # Demo only - set to false in production
  
  tags = {
    Name                    = "${var.db_identifier}"
    "compliance:nist-controls" = "SC-28,SC-28(1),AU-2,AU-9,CP-9,IA-5,SI-7"
    "compliance:impact-level"  = "moderate"
    "ato:criticality"          = "high"
    "ato:data-classification"  = "sensitive"
  }
}

# NIST 800-53: SC-28(1) - Cryptographic Protection
# KMS key for database encryption
resource "aws_kms_key" "database" {
  description             = "KMS key for RDS database encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  tags = {
    Name                       = "atlas-demo-db-key"
    "compliance:nist-controls" = "SC-12,SC-13,SC-28(1)"
    Purpose                    = "Database Encryption"
  }
}

resource "aws_kms_alias" "database" {
  name          = "alias/atlas-demo-database"
  target_key_id = aws_kms_key.database.key_id
}

# NIST 800-53: SC-7 - Boundary Protection
# Security group for database access
resource "aws_security_group" "database" {
  name        = "${var.db_identifier}-sg"
  description = "Security group for RDS database - restrict access to application only"
  
  # Allow PostgreSQL access only from Kubernetes pods
  ingress {
    description = "PostgreSQL from application"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # Kubernetes pod network
  }
  
  egress {
    description = "Allow outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name                       = "${var.db_identifier}-sg"
    "compliance:nist-controls" = "SC-7,SC-7(5)"
    Purpose                    = "Database Network Protection"
  }
}
```

### Variables Pattern

```hcl
# File: variables.tf
# Configuration variables for compliant infrastructure

variable "aws_region" {
  description = "AWS region for LocalStack"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for application storage"
  type        = string
  default     = "atlas-demo-storage"
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = "atlasdemodb"
}

variable "db_username" {
  description = "Master username for database"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for database (use Secrets Manager in production)"
  type        = string
  default     = "ChangeMeInProduction123!"
  sensitive   = true
}
```

### Outputs Pattern

```hcl
# File: outputs.tf
# NIST 800-53: CM-8 - Information System Component Inventory
# Outputs for integration and documentation

output "s3_bucket_name" {
  description = "S3 bucket name for application storage"
  value       = aws_s3_bucket.app_storage.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for compliance tracking"
  value       = aws_s3_bucket.app_storage.arn
}

output "db_host" {
  description = "PostgreSQL database host"
  value       = "postgres.default.svc.cluster.local"
}

output "db_port" {
  description = "PostgreSQL database port"
  value       = "5432"
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}

output "compliance_controls" {
  description = "NIST 800-53 controls implemented by this infrastructure"
  value = {
    s3_controls       = "SC-28,SC-28(1),AU-2,AU-9,CP-9,AC-6"
    postgres_controls = "SC-28,CP-9,IA-5,SC-7"
    k8s_controls      = "SC-7,AU-2,SI-2"
  }
}
```

## Kubernetes Deployment Patterns

### Controls Addressed
- **SC-28**: Protection of Information at Rest
- **IA-5**: Authenticator Management (secrets)
- **SC-7**: Boundary Protection
- **AU-2**: Audit Events
- **SI-2**: Flaw Remediation (container updates)

### Compliant Kubernetes Deployment

```hcl
# File: k8s-deployment.tf
# NIST 800-53: SC-7, SC-28, IA-5 - Secure Application Deployment

resource "kubernetes_deployment" "demo_api" {
  metadata {
    name = "atlas-demo-api"
    labels = {
      app                         = "atlas-demo-api"
      "compliance:nist-controls"  = "SC-7,SC-28,IA-5,AU-2"
      "ato:component-type"        = "application"
    }
  }

  spec {
    replicas = 2  # High availability

    selector {
      match_labels = {
        app = "atlas-demo-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "atlas-demo-api"
        }
      }

      spec {
        # NIST 800-53: SC-7 - Boundary Protection
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }

        container {
          name  = "api"
          image = "atlas-demo-api:latest"
          image_pull_policy = "IfNotPresent"

          # NIST 800-53: IA-5 - Authenticator Management
          # Database credentials passed as environment variables
          env {
            name  = "DB_HOST"
            value = "postgres.default.svc.cluster.local"
          }
          
          env {
            name  = "DB_PORT"
            value = "5432"
          }
          
          env {
            name  = "DB_NAME"
            value = var.db_name
          }
          
          env {
            name  = "DB_USER"
            value = var.db_username
          }
          
          env {
            name  = "DB_PASSWORD"
            value = var.db_password
            # Note: In production, use Kubernetes secrets or external secret manager
          }
          
          env {
            name  = "S3_BUCKET"
            value = aws_s3_bucket.app_storage.id
          }
          
          env {
            name  = "S3_ENDPOINT"
            value = "http://host.docker.internal:4566"  # LocalStack endpoint from Kind
          }
          
          env {
            name  = "AWS_ACCESS_KEY_ID"
            value = "test"
          }
          
          env {
            name  = "AWS_SECRET_ACCESS_KEY"
            value = "test"
          }
          
          env {
            name  = "NODE_ENV"
            value = "production"
          }

          port {
            container_port = 3000
            name          = "http"
          }

          # NIST 800-53: AU-2 - Health monitoring
          liveness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          # Resource limits for stability
          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          # NIST 800-53: SC-7 - Container security
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = false  # App needs write for logs
            run_as_non_root           = true
            run_as_user               = 1000
          }
        }
      }
    }
  }
}

# NIST 800-53: SC-7 - Boundary Protection
resource "kubernetes_service" "demo_api" {
  metadata {
    name = "atlas-demo-api"
    labels = {
      app = "atlas-demo-api"
    }
  }

  spec {
    selector = {
      app = "atlas-demo-api"
    }

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
      name        = "http"
    }

    type = "LoadBalancer"
  }
}
```

## Documentation Requirements

### Inline Comments
- Include `# NIST 800-53:` comments for each resource explaining which controls it implements
- Reference SSP sections where applicable
- Explain security decisions in comments

### Resource Tags
Every resource must include:
```hcl
tags = {
  "compliance:nist-controls" = "SC-28,AU-2,CP-9"  # Comma-separated control IDs
  "compliance:impact-level"  = "moderate"         # low, moderate, high
  "ato:criticality"         = "high"             # low, medium, high
  "ato:data-classification" = "sensitive"        # public, internal, sensitive, classified
}
```

### Outputs for Compliance
Generate outputs that can be used for:
- SSP generation
- Control implementation evidence
- Architecture documentation
- Audit trails

## Best Practices

### When Generating Terraform Code:

1. **Always include NIST control mappings** in comments and tags
2. **Enable encryption** for all data at rest (even in LocalStack)
3. **Use security groups** to implement least privilege network access
4. **Enable logging and monitoring** where available
5. **Tag all resources** with compliance metadata
6. **Document security decisions** in code comments
7. **Use variables** for sensitive values (even with defaults for demo)
8. **Include outputs** that aid in compliance documentation

### LocalStack Limitations

Be aware that LocalStack may not fully support all AWS features:
- Some encryption features may be simulated
- CloudWatch integration may be limited
- IAM policies may not be fully enforced

However, we maintain production patterns to ensure code can be promoted to real AWS environments.

## Compliance Artifact Generation

When asked to generate compliance documentation:

### Control Implementation Summary
Create a markdown file listing:
- Each NIST control implemented
- Which Terraform resources implement it
- Configuration details that satisfy the control
- Evidence location (file:line or resource name)

### Control Matrix
Create a CSV or table with:
- Control ID
- Control Family
- Implementing Resource(s)
- Implementation Status
- Evidence Location
- Notes

Example:
```csv
Control ID,Control Family,Resource,Implementation Status,Evidence,Notes
SC-28,System and Communications Protection,aws_db_instance.app_database,Implemented,rds.tf:15,Storage encryption enabled
SC-28(1),System and Communications Protection,aws_kms_key.database,Implemented,rds.tf:45,KMS key with rotation
AU-2,Audit and Accountability,aws_db_instance.app_database,Implemented,rds.tf:28,CloudWatch logs enabled
```

## Questions During Code Generation?

If unsure about a security configuration:
1. Default to most secure option
2. Add a TODO comment explaining the decision
3. Reference the relevant NIST control
4. Suggest validation with security team

---

**Remember:** Even in a demo environment, practice production-ready security patterns!
