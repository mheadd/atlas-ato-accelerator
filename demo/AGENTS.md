# NIST-Compliant Terraform Guidance for LocalStack

This guidance helps AI coding assistants generate NIST 800-53 compliant Terraform infrastructure code for LocalStack environments. While LocalStack simulates AWS services locally, we maintain the same security patterns that would be used in production environments.

## Purpose

Generate Terraform code that:
- Implements NIST 800-53 security controls from the start
- Uses secure baselines for all resources
- Includes compliance annotations and mappings
- Produces documentation suitable for ATO artifacts

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
    rds            = "http://localhost:4566"
    s3             = "http://localhost:4566"
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

## RDS Database Patterns

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

variable "db_identifier" {
  description = "Unique identifier for the RDS instance"
  type        = string
  default     = "atlas-demo-db"
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

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}
```

### Outputs Pattern

```hcl
# File: outputs.tf
# NIST 800-53: CM-8 - Information System Component Inventory
# Outputs for integration and documentation

output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.app_database.endpoint
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.app_database.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.app_database.db_name
}

output "db_arn" {
  description = "RDS instance ARN for compliance tracking"
  value       = aws_db_instance.app_database.arn
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = aws_kms_key.database.key_id
}

output "compliance_controls" {
  description = "NIST 800-53 controls implemented by this infrastructure"
  value = {
    rds_controls = "SC-28,SC-28(1),AU-2,AU-9,CP-9,IA-5,SI-7"
    kms_controls = "SC-12,SC-13,SC-28(1)"
    sg_controls  = "SC-7,SC-7(5)"
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
            value = split(":", aws_db_instance.app_database.endpoint)[0]
          }
          
          env {
            name  = "DB_PORT"
            value = tostring(aws_db_instance.app_database.port)
          }
          
          env {
            name  = "DB_NAME"
            value = aws_db_instance.app_database.db_name
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
