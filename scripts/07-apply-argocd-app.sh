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
sed "s|AWS_ACCOUNT_ID|$ACCOUNT_ID|g" argocd/application.yaml | kubectl apply -f - && \
echo "✅ Application applied."

# 4. Wait and check if the app is ready (Synced + Healthy)
echo "🔍 Checking application status for '$APP_NAME'..."
for i in {1..10}; do
  STATUS=$(argocd app get "$APP_NAME" --server=localhost:8085 --insecure -o json 2>/dev/null | jq -r '.status.sync.status // "unknown"')
  HEALTH=$(argocd app get "$APP_NAME" --server=localhost:8085 --insecure -o json 2>/dev/null | jq -r '.status.health.status // "unknown"')

  echo "⏳ Attempt $i: sync=$STATUS, health=$HEALTH"

  if [[ "$STATUS" == "Synced" && "$HEALTH" == "Healthy" ]]; then
    echo "✅ ArgoCD application '$APP_NAME' is ready: Synced + Healthy."
    exit 0
  fi

  sleep 10
done

echo "⚠️ Application '$APP_NAME' did not reach Synced + Healthy after 10 attempts. Continuing gracefully."
