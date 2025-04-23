#!/bin/bash
set -e
echo "🌐 Applying ArgoCD Ingress..."
kubectl apply -f manifests/argocd-ingress.yaml
