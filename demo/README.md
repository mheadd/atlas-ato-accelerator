# ATLAS ATO Accelerator Demo

This demo showcases how AI coding assistants can generate NIST-compliant Terraform infrastructure code using the AGENTS.md guidance file. You'll deploy a simple containerized CRUD API to a local Kubernetes cluster with AWS services running in LocalStack.

## Prerequisites

Before starting, ensure you have the following tools installed:

### Quick Setup (Recommended)

Run the automated setup script to check and install prerequisites:

```bash
cd demo
./setup.sh
```

This script will:
- Check if all required tools are installed
- Offer to install missing tools via Homebrew (macOS)
- Let you choose between Colima (free) or Docker Desktop
- Verify versions of installed tools

### Manual Installation

If you prefer to install tools manually, here are the requirements:

### Required Tools

- **Container Runtime** - Choose one:
  
  **Option A: Docker Desktop** (Commercial license required for large organizations)
  ```bash
  docker --version  # Should be 20.10+
  ```
  Install: https://www.docker.com/products/docker-desktop/

  **Option B: Colima** (Free, open-source alternative for macOS/Linux)
  ```bash
  colima --version  # Should be 0.5+
  docker --version  # Colima provides Docker CLI
  ```
  Install on macOS: `brew install colima`
  
  Start Colima:
  ```bash
  colima start --cpu 4 --memory 8
  ```
  
  See: https://github.com/abiosoft/colima

- **Kind** (Kubernetes in Docker) - Local Kubernetes cluster
  ```bash
  kind --version  # Should be 0.20+
  ```
  Install: `brew install kind` (macOS) or see https://kind.sigs.k8s.io/docs/user/quick-start/#installation

- **kubectl** - Kubernetes CLI
  ```bash
  kubectl version --client  # Should be 1.28+
  ```
  Install: `brew install kubectl` (macOS) or see https://kubernetes.io/docs/tasks/tools/

- **Terraform** - Infrastructure as Code
  ```bash
  terraform version  # Should be 1.5+
  ```
  Install: `brew install terraform` (macOS) or see https://www.terraform.io/downloads

- **LocalStack** - Local AWS cloud stack
  ```bash
  pip install localstack  # or use Docker
  localstack --version  # Should be 3.0+
  ```
  Install: `pip install localstack` or see https://docs.localstack.cloud/getting-started/installation/
  
  **Note:** The free Community edition includes S3, IAM, and other basic services. RDS requires a Pro license, so this demo uses PostgreSQL running in Kubernetes with S3 for file storage.

- **Helm** - Kubernetes package manager
  ```bash
  helm version  # Should be 3.12+
  ```
  Install: `brew install helm` (macOS) or see https://helm.sh/docs/intro/install/

- **AWS CLI** - For interacting with LocalStack
  ```bash
  aws --version  # Should be 2.0+
  ```
  Install: `brew install awscli` (macOS) or see https://aws.amazon.com/cli/

### Optional but Recommended

- **jq** - JSON processor for pretty output
  ```bash
  brew install jq
  ```

## Demo Setup

### Step 0: Verify Container Runtime

Before proceeding, ensure your container runtime is running:

**If using Docker Desktop:**
```bash
# Check if Docker is running
docker ps

# If not running, start Docker Desktop from Applications
```

**If using Colima:**
```bash
# Check if Colima is running
colima status

# If not running, start Colima
colima start --cpu 4 --memory 8

# Verify Docker is working
docker ps
```

### Step 1: Start LocalStack

Start LocalStack to simulate AWS services locally:

```bash
# Start LocalStack with RDS support
localstack start -d

# Verify LocalStack is running
localstack status

# You should see services like RDS, S3, etc. available
```

LocalStack will be available at `http://localhost:4566`

Configure AWS CLI to use LocalStack:

```bash
# Configure AWS CLI for LocalStack (use dummy credentials)
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Test connection (S3 is available in free tier)
aws --endpoint-url=http://localhost:4566 s3 ls
```

### Step 2: Create Kind Cluster

Create a local Kubernetes cluster:

```bash
# Create a Kind cluster named 'atlas-demo'
kind create cluster --name atlas-demo

# Verify cluster is running
kubectl cluster-info --context kind-atlas-demo

# Check nodes
kubectl get nodes
```

### Step 3: Build Demo Application

Build the demo CRUD API container:

```bash
# Navigate to the app directory
cd demo/app

# Build the Docker image
docker build -t atlas-demo-api:latest .

# Load the image into Kind cluster
kind load docker-image atlas-demo-api:latest --name atlas-demo

# Return to demo directory
cd ..
```

## Demo Walkthrough

Now you're ready to use AI assistance to generate NIST-compliant infrastructure code!

### Phase 1: Generate AWS Infrastructure (Terraform)

Open your AI coding assistant (Claude, GitHub Copilot, etc.) in your IDE. The assistant will automatically read the `AGENTS.md` file in this directory.

**Prompt 1: Generate S3 Bucket for Application Data**

```
Create Terraform configuration for an S3 bucket in LocalStack that will be used 
for storing application file uploads. The bucket should be NIST-compliant 
following the patterns in AGENTS.md. Store the configuration in demo/tf/s3.tf
```

Expected output: Terraform file with encrypted S3 bucket, versioning, logging, proper tagging, and NIST control mappings.

**Prompt 2: Generate Terraform Provider Configuration**

```
Create the Terraform provider configuration for LocalStack in demo/tf/provider.tf,
configured to work with LocalStack running at http://localhost:4566
```

**Prompt 3: Generate Terraform Variables**

```
Create a variables file in demo/tf/variables.tf for the infrastructure configuration,
including bucket name, AWS region, and environment settings
```

**Prompt 4: Generate Terraform Outputs**

```
Create outputs in demo/tf/outputs.tf that will expose the S3 bucket name and ARN
for use by our application
```

### Phase 2: Apply Infrastructure

Apply the generated Terraform:

```bash
cd demo/tf

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply -auto-approve

# Save outputs for later use
terraform output -json > outputs.json
```

### Phase 3: Generate Kubernetes Deployment

**Prompt 5: Generate PostgreSQL Database Deployment**

```
Create a Kubernetes StatefulSet manifest in demo/tf/k8s-postgres.tf using the 
Terraform Kubernetes provider. Deploy a PostgreSQL database with persistent 
storage for our demo API. Include NIST-compliant security configurations.
```

**Prompt 6: Generate Application Deployment**

```
Create a Kubernetes deployment manifest in demo/tf/k8s-deployment.tf using the 
Terraform Kubernetes provider. Deploy the atlas-demo-api:latest container with 
environment variables for database connectivity and S3 bucket access. Include 
resource limits and health checks.
```

**Prompt 7: Generate Kubernetes Service**

```
Create a Kubernetes service manifest in demo/tf/k8s-service.tf to expose the 
demo API on port 3000 as a LoadBalancer type service.
```

Apply the Kubernetes resources:

```bash
# Apply the Kubernetes manifests
terraform apply -auto-approve

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=atlas-demo-api --timeout=60s

# Check deployment status
kubectl get pods
kubectl get services
```

### Phase 4: Test the Application

Get the service endpoint:

```bash
# For Kind cluster, use port-forward to access the service
kubectl port-forward service/atlas-demo-api 3000:3000 &

# Test the API
curl http://localhost:3000/health

# Create a new item
curl -X POST http://localhost:3000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "Created via NIST-compliant infrastructure"}'

# Get all items
curl http://localhost:3000/api/items

# Get specific item (replace {id} with actual ID from create response)
curl http://localhost:3000/api/items/{id}

# Update item
curl -X PUT http://localhost:3000/api/items/{id} \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Item", "description": "Modified"}'

# Delete item
curl -X DELETE http://localhost:3000/api/items/{id}
```

### Phase 5: Generate Compliance Documentation

**Prompt 8: Generate Compliance Report**

```
Analyze the Terraform files in demo/tf/ and generate a compliance summary document
in demo/ato/compliance-summary.md that lists all NIST 800-53 controls that have been
implemented, which resources implement each control, and the specific configurations
that satisfy each control requirement.
```

**Prompt 9: Generate Control Implementation Matrix**

```
Create a control implementation matrix in demo/ato/control-matrix.csv that maps
each Terraform resource to the NIST controls it implements, including the control
family, implementation status, and evidence location.
```

Review the generated compliance artifacts:

```bash
# View compliance summary
cat demo/ato/compliance-summary.md

# View control matrix
cat demo/ato/control-matrix.csv
```

## Cleanup

When you're done with the demo:

```bash
# Destroy Terraform resources
cd demo/tf
terraform destroy -auto-approve

# Delete Kind cluster
kind delete cluster --name atlas-demo

# Stop LocalStack
localstack stop
```

## What This Demonstrates

This demo showcases:

1. **AI-Assisted Compliance** - Using AGENTS.md guidance to generate NIST-compliant infrastructure code
2. **Shift-Left Security** - Security controls embedded from the start, not added later
3. **Infrastructure as Code** - Declarative, version-controlled infrastructure
4. **Documentation Generation** - Compliance artifacts created from the infrastructure code itself
5. **Local Development** - Full cloud-native stack running locally for development and testing

## Key Takeaways

- ✅ Infrastructure code is generated with NIST controls built-in
- ✅ Compliance documentation is derived from the code, not separately maintained
- ✅ Developers can create secure infrastructure without deep security expertise
- ✅ The same patterns work for production AWS/cloud environments
- ✅ Reduces ATO preparation time by embedding compliance early

## Troubleshooting

### LocalStack Issues

```bash
# Check LocalStack logs
localstack logs

# Restart LocalStack
localstack stop
localstack start -d
```

### Kind Cluster Issues

```bash
# Check cluster status
kubectl cluster-info dump

# Recreate cluster
kind delete cluster --name atlas-demo
kind create cluster --name atlas-demo
```

### Application Issues

```bash
# Check pod logs
kubectl logs -l app=atlas-demo-api

# Check pod description
kubectl describe pod -l app=atlas-demo-api

# Rebuild and reload image
cd demo/app
docker build -t atlas-demo-api:latest .
kind load docker-image atlas-demo-api:latest --name atlas-demo
kubectl rollout restart deployment atlas-demo-api
```

## Next Steps

After completing this demo, explore:

- Expanding to additional AWS services (S3, Secrets Manager, CloudWatch)
- Adding more NIST controls (network segmentation, monitoring, etc.)
- Deploying to a real AWS environment
- Integrating with CI/CD pipelines
- Using policy-as-code validation (OPA/Sentinel)

---

**Questions or Issues?** See the main [README](../README.md) and [PROPOSAL](../PROPOSAL.md) for more details.
