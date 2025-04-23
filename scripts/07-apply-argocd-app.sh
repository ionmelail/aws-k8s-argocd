#!/bin/bash
set -e

echo "🚀 Applying ArgoCD application..."
ACCOUNT_ID=${1:-"unknown"}
sed "s|AWS_ACCOUNT_ID|$ACCOUNT_ID|g" manifests/application.yaml | kubectl apply -f -
