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
  
  # CRITICAL: LocalStack requires path-style S3 URLs
  s3_use_path_style = true

  endpoints {
    s3             = "http://localhost:4566"
    iam            = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    kms            = "http://localhost:4566"
  }

  default_tags {
    tags = {
      Environment         = "demo"
      ManagedBy          = "terraform"
      ComplianceFramework = "NIST-800-53"
      Project            = "atlas-ato-accelerator"
    }
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
    Name                = var.bucket_name
    ComplianceControls  = "SC-28_SC-28-1_AU-2_AU-9_CP-9_AC-6"
    ComplianceLevel     = "moderate"
    AtoCriticality      = "high"
    DataClassification  = "sensitive"
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
    Name               = "${var.bucket_name}-logs"
    ComplianceControls = "AU-2_AU-9"
    Purpose            = "AccessLogs"
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

**Important Notes for S3 Configuration:**
- **Do NOT add lifecycle rules** unless specifically requested - they add complexity and can cause validation errors in LocalStack
- Keep the configuration focused on core security controls: encryption, versioning, logging, and public access blocking
- LocalStack may not support all AWS S3 features - stick to basics
- If lifecycle rules are needed, always include either a `filter` block or `prefix` attribute in each rule

### LocalStack-Compatible Tagging Standards

**CRITICAL:** LocalStack is stricter about tag formatting than AWS. Follow these rules:

**Tag Key Naming:**
- ❌ **DON'T** use colons: `"compliance:nist-controls"`
- ❌ **DON'T** use hyphens in keys: `"ato:data-classification"`
- ✅ **DO** use PascalCase: `"ComplianceControls"`, `"DataClassification"`

**Tag Value Formatting:**
- ❌ **DON'T** use commas: `"SC-28,AU-2,CP-9"`
- ❌ **DON'T** use parentheses: `"SC-28(1)"`
- ❌ **DON'T** use spaces: `"Access Logs"`
- ✅ **DO** use underscores as separators: `"SC-28_AU-2_CP-9"`
- ✅ **DO** replace parentheses with hyphens: `"SC-28-1"` instead of `"SC-28(1)"`
- ✅ **DO** use PascalCase for multi-word values: `"AccessLogs"`

**Standard Tag Schema for All Resources:**
```hcl
tags = {
  Name                = "resource-name"
  ComplianceControls  = "SC-28_SC-28-1_AU-2_AU-9"  # Underscore-separated NIST control IDs
  ComplianceLevel     = "moderate"                  # low, moderate, high
  AtoCriticality      = "high"                      # low, medium, high
  DataClassification  = "sensitive"                 # public, internal, sensitive, classified
  Purpose             = "ApplicationStorage"        # Brief description in PascalCase
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

### Important PostgreSQL Deployment Considerations

**NetworkPolicy Egress Rules:**
- ❌ **DON'T** use empty `to` blocks in egress rules - this is invalid
- ✅ **DO** omit the `to` block entirely to allow "any destination"
- Example: For unrestricted egress, use `egress { ports { ... } }` without a `to` block

**Database Initialization:**
- PostgreSQL's automatic database creation expects default settings
- Custom `postgresql.conf` configurations may interfere with initialization
- Test database creation with your config before applying custom settings
- If using custom configs, ensure they don't conflict with `POSTGRES_DB` environment variable

**Authentication Testing:**
- Always test with the intended authentication method
- Network connections use `md5` or `scram-sha-256` authentication
- Local socket connections may use `trust` or `peer` authentication
- Verify `pg_hba.conf` settings match your deployment method (network vs local)
- Test connectivity from application pods, not just within the database pod

### Compliant PostgreSQL StatefulSet

```hcl
# File: k8s-postgres.tf
# NIST 800-53: SC-28, CP-9 - Database with Persistent Storage

resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name = "postgres"
    labels = {
      app                = "postgres"
      ComplianceControls = "SC-28_CP-9_IA-5_SC-7"
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
    Name               = "${var.db_identifier}"
    ComplianceControls = "SC-28_SC-28-1_AU-2_AU-9_CP-9_IA-5_SI-7"
    ComplianceLevel    = "moderate"
    AtoCriticality     = "high"
    DataClassification = "sensitive"
  }
}

# NIST 800-53: SC-28(1) - Cryptographic Protection
# KMS key for database encryption
resource "aws_kms_key" "database" {
  description             = "KMS key for RDS database encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  tags = {
    Name               = "atlas-demo-db-key"
    ComplianceControls = "SC-12_SC-13_SC-28-1"
    Purpose            = "DatabaseEncryption"
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
    Name               = "${var.db_identifier}-sg"
    ComplianceControls = "SC-7_SC-7-5"
    Purpose            = "DatabaseNetworkProtection"
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

**Important Notes for Variables:**
- **Do NOT add custom validation rules** for passwords in demo environments - the default value may not pass complex validation
- Keep variable definitions simple and straightforward
- Validation should be added in production environments, not demos
- Sensitive variables should be marked with `sensitive = true`

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
    s3_controls       = "SC-28_SC-28-1_AU-2_AU-9_CP-9_AC-6"
    postgres_controls = "SC-28_CP-9_IA-5_SC-7"
    k8s_controls      = "SC-7_AU-2_SI-2"
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
      app                = "atlas-demo-api"
      ComplianceControls = "SC-7_SC-28_IA-5_AU-2"
      AtoComponentType   = "application"
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
    
    # NIST 800-53: SC-7 - Additional security controls
    external_traffic_policy = "Local"  # Preserve source IP
    session_affinity       = "ClientIP"  # Session persistence
  }
}
```

### Important: LoadBalancer Services in Kind

**Expected Behavior:**
- LoadBalancer services will remain in **"Pending"** status in Kind clusters
- This is **normal** - Kind doesn't provide a built-in load balancer implementation
- The service is still **fully functional** for internal cluster communication
- Access the service using `kubectl port-forward` for local testing

**Why This Configuration Is Still Valuable:**
- ✅ **Production-ready**: The exact same code works in cloud environments (AWS, GCP, Azure)
- ✅ **NIST-compliant**: Includes all security features (external traffic policy, session affinity)
- ✅ **No code changes**: Deploy to cloud without modifications
- ✅ **Best practices**: Demonstrates proper service configuration patterns

**Testing in Kind:**
```bash
# Service will show <pending> for EXTERNAL-IP - this is expected
kubectl get svc atlas-demo-api

# Access via port-forward for local testing
kubectl port-forward service/atlas-demo-api 3000:3000

# Or use internal service discovery from other pods
# Service is accessible at: atlas-demo-api.default.svc.cluster.local:3000
```

**In Production Cloud Environments:**
- Cloud providers automatically provision load balancers
- External IP is assigned within 1-2 minutes
- Service becomes publicly accessible
- All NIST compliance features are active

## Documentation Requirements

### Inline Comments
- Include `# NIST 800-53:` comments for each resource explaining which controls it implements
- Reference SSP sections where applicable
- Explain security decisions in comments

### Resource Tags (LocalStack-Compatible Format)
Every resource must include tags following this format:
```hcl
tags = {
  ComplianceControls  = "SC-28_AU-2_CP-9"  # Underscore-separated NIST control IDs
  ComplianceLevel     = "moderate"         # low, moderate, high
  AtoCriticality      = "high"            # low, medium, high
  DataClassification  = "sensitive"        # public, internal, sensitive, classified
}
```

**Critical formatting rules:**
- Use **PascalCase** for tag keys (no colons or hyphens)
- Use **underscores** to separate multiple control IDs
- Replace parentheses with hyphens: `SC-28-1` not `SC-28(1)`
- Use **PascalCase** for multi-word values, no spaces

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

### Demo-Specific Guidelines:

**Keep It Simple:**
- Avoid complex validation rules on variables that have default values
- Don't add lifecycle policies unless explicitly requested
- Stick to core security features that work reliably in LocalStack
- Focus on demonstrating concepts, not production-level complexity

**Common Pitfalls to Avoid:**
- ❌ **DON'T** add password validation rules when providing a default password
- ❌ **DON'T** add lifecycle rules without proper `filter` or `prefix` attributes
- ❌ **DON'T** use advanced AWS features that require LocalStack Pro
- ❌ **DON'T** over-engineer the demo - simple, working code is better
- ❌ **DON'T** use colons, commas, or parentheses in tag keys or values
- ❌ **DON'T** forget `s3_use_path_style = true` in the AWS provider
- ❌ **DON'T** use complex regex with lookahead assertions in Terraform validation
- ❌ **DON'T** use empty `to` blocks in NetworkPolicy egress rules (omit entirely for "any destination")
- ❌ **DON'T** add custom PostgreSQL configs without testing database initialization
- ❌ **DON'T** assume local socket authentication works the same as network authentication
- ❌ **DON'T** expect LoadBalancer services to get external IPs in Kind (use port-forward instead)
- ✅ **DO** focus on NIST control implementation
- ✅ **DO** include proper tagging and documentation (following LocalStack-compatible format)
- ✅ **DO** use security best practices (encryption, least privilege, etc.)
- ✅ **DO** test that resources will work with LocalStack free tier
- ✅ **DO** use PascalCase for tag keys and underscore separators for list values
- ✅ **DO** use simple regex patterns like `can(regex("pattern", var.value))` for validation
- ✅ **DO** test database connectivity from application pods
- ✅ **DO** verify pg_hba.conf settings match your deployment method
- ✅ **DO** use LoadBalancer type services even in Kind (production-ready, works via port-forward locally)

### Critical LocalStack-Specific Settings

**Always include these in generated code:**

1. **AWS Provider Configuration:**
   - `s3_use_path_style = true` - Required for LocalStack S3 compatibility
   - All endpoint URLs should point to `http://localhost:4566`
   - Use `skip_credentials_validation = true`

2. **S3 Resources:**
   - Use path-style URLs, not virtual hosted-style
   - Lifecycle rules must have `filter {}` or `prefix = "value"`
   - Keep tags simple (PascalCase keys, underscore-separated values)

3. **Variables:**
   - Avoid complex validation for demo defaults
   - Use simple `can(regex())` patterns if validation is needed
   - Don't validate passwords with lookahead assertions

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
