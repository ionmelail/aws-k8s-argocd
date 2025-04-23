#!/bin/bash
set -e

echo "🌐 Applying ArgoCD Ingress with validation disabled (webhook workaround)..."
kubectl apply -f manifests/argocd-ingress.yaml --validate=false
