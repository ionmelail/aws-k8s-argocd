#!/bin/bash
echo "Patching argocd-server service to ClusterIP..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}'
