#!/bin/bash
set -euo pipefail

echo "🚀 Installing NGINX Ingress Controller on EKS..."

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.serviceAccount.name=ingress-nginx-controller \
  --set controller.serviceAccount.create=false \
  --set controller.replicaCount=2 \
  --wait

echo "⏳ Waiting for NGINX LoadBalancer external hostname..."
for i in {1..20}; do
  LB_HOSTNAME=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

  if [[ -n "$LB_HOSTNAME" ]]; then
    echo "✅ NGINX LoadBalancer is available:"
    echo "🔗 http://$LB_HOSTNAME"
    break
  fi

  echo "⏳ Still waiting... ($i/20)"
  sleep 10
done

if [[ -z "$LB_HOSTNAME" ]]; then
  echo "❌ LoadBalancer was not assigned in time. Exiting."
  exit 1
fi

# Patch ArgoCD service to ClusterIP
echo "🔧 Patching ArgoCD server service to ClusterIP..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "ClusterIP"}}' || {
  echo "❌ Failed to patch argocd-server service. Exiting."
  exit 1
}

# Apply ArgoCD Ingress
echo "📦 Applying ArgoCD Ingress resource..."
kubectl apply -f argocd/argocd-server-ingress.yaml || {
  echo "❌ Failed to apply ArgoCD Ingress. Exiting."
  exit 1
}

echo "✅ ArgoCD is now accessible via:"
echo "🔗 https://$LB_HOSTNAME"
