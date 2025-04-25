#!/bin/bash
set -euo pipefail

echo "🚀 Applying ArgoCD application..."

ACCOUNT_ID=${1:-"unknown"}
APP_NAME="demo-app"
NAMESPACE="argocd"

# 1. Verify AWS account ID is provided
if [[ "$ACCOUNT_ID" == "unknown" ]]; then
  echo "❌ AWS Account ID not provided. Skipping ArgoCD app apply."
  exit 0
fi

# 2. Check if ArgoCD Application CRD is installed
if ! kubectl get crd applications.argoproj.io &>/dev/null; then
  echo "⚠️ ArgoCD Application CRD not found. Skipping."
  exit 0
fi

# 3. Apply the app manifest with the account ID substituted
echo "📦 Applying application.yaml..."
sed "s|AWS_ACCOUNT_ID|$ACCOUNT_ID|g" argocd/application.yaml | kubectl apply -f -

echo "✅ Application applied."
