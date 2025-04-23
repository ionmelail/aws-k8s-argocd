#!/bin/bash

# Sample IAM definitions for EKS

# Define all necessary environment variables at the beginning
AWS_REGION="us-west-2"  # Change this to your AWS region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
ECR_REPO_NAME="demo-app"
DOCKER_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest"
GITHUB_USERNAME="imelnic555"
GITHUB_TOKEN="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"
# GITHUB_REPO="https://${GITHUB_USERNAME}::${{ secrets.GH_PATD }}@github.com/imelnic555/demo.git"
GITHUB_REPO="https://github.com/imelnic555/demo.git"

CLONE_DIR="demo-app"

############################################
# Ensure AWS credentials are set
############################################

echo "🔍 Checking AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ ERROR: AWS credentials are missing or invalid."
    echo "🔹 Run 'aws configure' locally OR set them in GitHub Secrets."
    exit 1
fi

############################################
# Install ArgoCD CLI if not installed
############################################

if ! command -v argocd &> /dev/null; then
    echo "🔧 ArgoCD CLI not found. Installing..."
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd
fi





############################################
# Clone the Demo Repository
############################################

echo "📥 Cloning the demo repository..."
if [ -d "$CLONE_DIR" ]; then
    echo "✅ Repository already cloned. Pulling latest changes..."
    cd "$CLONE_DIR"
    git pull origin main
    cd ..
else
    git clone "$GITHUB_REPO" "$CLONE_DIR"
fi

############################################
# Build and Push Docker Image (BEFORE Syncing)
############################################

# Ensure Dockerfile exists before building
if [ ! -f "$CLONE_DIR/dockerfile" ]; then
    echo "❌ ERROR: Dockerfile not found in the cloned repository."
    exit 1
fi

echo "🔑 Logging into AWS ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo "📦 Creating ECR repository if not exists..."
aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION >/dev/null 2>&1 || \
aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION

echo "⚙️ Building Docker image..."
docker build -t demo-app:latest "$CLONE_DIR"

echo "🏷️ Tagging Docker image with AWS ECR URL..."
docker tag demo-app:latest $DOCKER_IMAGE

echo "🚀 Pushing Docker image to AWS ECR..."
docker push $DOCKER_IMAGE

