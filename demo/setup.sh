#!/bin/bash

# ATLAS ATO Accelerator Demo - Prerequisites Setup Script
# Copyright 2025 Mark Headd
# Licensed under the Apache License, Version 2.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${YELLOW}Warning: This script is optimized for macOS. Some commands may need adjustment for your OS.${NC}"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ATLAS ATO Accelerator Demo Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check version
check_version() {
    local cmd=$1
    local version_cmd=$2
    echo -e "${BLUE}Checking $cmd version...${NC}"
    eval "$version_cmd" || echo -e "${YELLOW}Could not determine version${NC}"
    echo ""
}

# Track what needs to be installed
NEEDS_INSTALL=()

echo -e "${BLUE}Checking prerequisites...${NC}\n"

# Check Homebrew (required for macOS installations)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command_exists brew; then
        echo -e "${RED}✗ Homebrew not found${NC}"
        echo -e "${YELLOW}Homebrew is required to install other tools on macOS${NC}"
        read -p "Install Homebrew now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
            echo -e "${RED}Cannot proceed without Homebrew. Exiting.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Homebrew installed${NC}"
    fi
    echo ""
fi

# Check Container Runtime (Docker or Colima)
echo -e "${BLUE}Container Runtime:${NC}"
if command_exists docker; then
    echo -e "${GREEN}✓ Docker found${NC}"
    check_version "Docker" "docker --version"
    
    # Check if Colima is running (if installed)
    if command_exists colima; then
        if colima status >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Colima is running${NC}"
        else
            echo -e "${YELLOW}! Colima is installed but not running${NC}"
            echo -e "${YELLOW}  Start with: colima start --cpu 4 --memory 8${NC}"
        fi
    fi
else
    echo -e "${RED}✗ Docker not found${NC}"
    echo -e "${YELLOW}You need either Docker Desktop or Colima${NC}"
    NEEDS_INSTALL+=("docker-runtime")
fi
echo ""

# Check Kind
echo -e "${BLUE}Kubernetes in Docker (Kind):${NC}"
if command_exists kind; then
    echo -e "${GREEN}✓ Kind installed${NC}"
    check_version "Kind" "kind --version"
else
    echo -e "${RED}✗ Kind not found${NC}"
    NEEDS_INSTALL+=("kind")
fi

# Check kubectl
echo -e "${BLUE}Kubernetes CLI (kubectl):${NC}"
if command_exists kubectl; then
    echo -e "${GREEN}✓ kubectl installed${NC}"
    check_version "kubectl" "kubectl version --client --short 2>/dev/null || kubectl version --client"
else
    echo -e "${RED}✗ kubectl not found${NC}"
    NEEDS_INSTALL+=("kubectl")
fi

# Check Terraform
echo -e "${BLUE}Terraform:${NC}"
if command_exists terraform; then
    echo -e "${GREEN}✓ Terraform installed${NC}"
    check_version "Terraform" "terraform version"
else
    echo -e "${RED}✗ Terraform not found${NC}"
    NEEDS_INSTALL+=("terraform")
fi

# Check LocalStack
echo -e "${BLUE}LocalStack:${NC}"
if command_exists localstack; then
    echo -e "${GREEN}✓ LocalStack installed${NC}"
    check_version "LocalStack" "localstack --version"
else
    echo -e "${RED}✗ LocalStack not found${NC}"
    NEEDS_INSTALL+=("localstack")
fi

# Check Helm
echo -e "${BLUE}Helm:${NC}"
if command_exists helm; then
    echo -e "${GREEN}✓ Helm installed${NC}"
    check_version "Helm" "helm version --short"
else
    echo -e "${RED}✗ Helm not found${NC}"
    NEEDS_INSTALL+=("helm")
fi

# Check AWS CLI
echo -e "${BLUE}AWS CLI:${NC}"
if command_exists aws; then
    echo -e "${GREEN}✓ AWS CLI installed${NC}"
    check_version "AWS CLI" "aws --version"
else
    echo -e "${RED}✗ AWS CLI not found${NC}"
    NEEDS_INSTALL+=("awscli")
fi

# Check optional tools
echo -e "${BLUE}Optional Tools:${NC}"
if command_exists jq; then
    echo -e "${GREEN}✓ jq installed${NC}"
else
    echo -e "${YELLOW}○ jq not found (optional but recommended)${NC}"
    NEEDS_INSTALL+=("jq")
fi
echo ""

# Check Python/pip for LocalStack
needs_localstack=false
for tool in "${NEEDS_INSTALL[@]}"; do
    if [[ "$tool" == "localstack" ]]; then
        needs_localstack=true
        break
    fi
done

if [[ "$needs_localstack" == true ]]; then
    if command_exists python3; then
        echo -e "${GREEN}✓ Python3 found (needed for LocalStack)${NC}"
    else
        echo -e "${YELLOW}! Python3 not found but may be needed for LocalStack${NC}"
    fi
    echo ""
fi

# Summary
echo -e "${BLUE}========================================${NC}"
if [ ${#NEEDS_INSTALL[@]} -eq 0 ]; then
    echo -e "${GREEN}All prerequisites are installed!${NC}"
    echo -e "${GREEN}You're ready to run the demo.${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "  1. Start LocalStack: ${BLUE}localstack start -d${NC}"
    echo -e "  2. Create Kind cluster: ${BLUE}kind create cluster --name atlas-demo${NC}"
    echo -e "  3. Follow the demo instructions in README.md"
    exit 0
fi

echo -e "${YELLOW}Missing prerequisites: ${#NEEDS_INSTALL[@]}${NC}"
echo ""

# Offer to install missing tools
read -p "Would you like to install the missing tools now? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled. Please install the missing tools manually.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Installing missing prerequisites...${NC}\n"

# Install missing tools
for tool in "${NEEDS_INSTALL[@]}"; do
    case $tool in
        docker-runtime)
            echo -e "${BLUE}Installing Docker runtime...${NC}"
            echo -e "${YELLOW}Choose your container runtime:${NC}"
            echo "1) Colima (Free, open-source)"
            echo "2) Docker Desktop (Requires license for commercial use)"
            read -p "Enter choice (1 or 2): " -n 1 -r
            echo
            if [[ $REPLY == "1" ]]; then
                brew install colima
                echo -e "${GREEN}✓ Colima installed${NC}"
                echo -e "${BLUE}Starting Colima...${NC}"
                colima start --cpu 4 --memory 8
            else
                echo -e "${YELLOW}Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/${NC}"
                echo -e "${YELLOW}Then re-run this script${NC}"
                exit 1
            fi
            ;;
        kind)
            echo -e "${BLUE}Installing Kind...${NC}"
            brew install kind
            echo -e "${GREEN}✓ Kind installed${NC}"
            ;;
        kubectl)
            echo -e "${BLUE}Installing kubectl...${NC}"
            brew install kubectl
            echo -e "${GREEN}✓ kubectl installed${NC}"
            ;;
        terraform)
            echo -e "${BLUE}Installing Terraform...${NC}"
            brew tap hashicorp/tap
            brew install hashicorp/tap/terraform
            echo -e "${GREEN}✓ Terraform installed${NC}"
            ;;
        localstack)
            echo -e "${BLUE}Installing LocalStack...${NC}"
            if command_exists pip3; then
                pip3 install localstack
            elif command_exists pip; then
                pip install localstack
            else
                echo -e "${RED}pip not found. Please install Python first.${NC}"
                exit 1
            fi
            echo -e "${GREEN}✓ LocalStack installed${NC}"
            ;;
        helm)
            echo -e "${BLUE}Installing Helm...${NC}"
            brew install helm
            echo -e "${GREEN}✓ Helm installed${NC}"
            ;;
        awscli)
            echo -e "${BLUE}Installing AWS CLI...${NC}"
            brew install awscli
            echo -e "${GREEN}✓ AWS CLI installed${NC}"
            ;;
        jq)
            echo -e "${BLUE}Installing jq...${NC}"
            brew install jq
            echo -e "${GREEN}✓ jq installed${NC}"
            ;;
    esac
    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Start LocalStack: ${BLUE}localstack start -d${NC}"
echo -e "  2. Create Kind cluster: ${BLUE}kind create cluster --name atlas-demo${NC}"
echo -e "  3. Follow the demo instructions in README.md"
echo ""
echo -e "${YELLOW}Note: If you installed Colima, make sure it's running:${NC}"
echo -e "  ${BLUE}colima status${NC}"
echo -e "  ${BLUE}colima start --cpu 4 --memory 8${NC} (if not running)"
