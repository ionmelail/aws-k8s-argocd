#!/bin/bash
set -e
echo "🔧 Patching ArgoCD server service to ClusterIP..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}'
