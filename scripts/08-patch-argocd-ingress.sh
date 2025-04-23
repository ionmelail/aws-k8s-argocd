#!/bin/bash
set -e

echo "🔧 Patching ArgoCD Server Service to ClusterIP..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}'

echo "🌐 Waiting for NGINX Ingress external IP or hostname..."
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

if [[ -n "$INGRESS_IP" ]]; then
  ARGOCD_HOST="argocd.${INGRESS_IP}.nip.io"
else
  INGRESS_HOST=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  ARGOCD_HOST="argocd.${INGRESS_HOST}"
fi

echo "🌐 Using ArgoCD Host: $ARGOCD_HOST"

echo "⚙️ Patching and applying ArgoCD Ingress with new host..."
sed "s|HOST_PLACEHOLDER|$ARGOCD_HOST|g" manifests/argocd-ingress.yaml | kubectl apply -f -
