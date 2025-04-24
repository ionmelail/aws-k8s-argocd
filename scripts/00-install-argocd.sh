#!/bin/bash
set -euo pipefail

NAMESPACE="argocd"
ADMIN_PASSWORD_BCRYPT='$2a$10$wEJ.NXBfjRj9JQ0QeqA1OuD4/2H6pRxH3p80fD/QFOhH8sD/jq12y'

echo "🔑 Ensuring ArgoCD admin secret exists..."
if ! kubectl get secret argocd-secret -n $NAMESPACE > /dev/null 2>&1; then
  kubectl create secret generic argocd-secret \
    -n $NAMESPACE \
    --from-literal=admin.password="$ADMIN_PASSWORD_BCRYPT"
  echo "✅ ArgoCD admin secret created."
else
  echo "✅ ArgoCD admin secret already exists."
fi

echo "📦 Installing ArgoCD into namespace '$NAMESPACE'..."
kubectl apply -n $NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Waiting for ArgoCD pods to be ready..."
for i in {1..30}; do
  READY_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | awk '{print $2}' | grep -c "1/1" || true)
  TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)

  if [[ "$READY_PODS" -eq "$TOTAL_PODS" && "$TOTAL_PODS" -gt 0 ]]; then
    echo "✅ All ArgoCD pods are ready! ($READY_PODS/$TOTAL_PODS)"
    break
  fi

  echo "⏳ Waiting... $READY_PODS/$TOTAL_PODS pods are ready."
  sleep 10
done

# Final check after loop
if [[ "$READY_PODS" -ne "$TOTAL_PODS" || "$TOTAL_PODS" -eq 0 ]]; then
  echo "❌ Error: ArgoCD pods failed to reach 1/1 READY state."
  kubectl get pods -n $NAMESPACE
  exit 1
fi

echo "🔓 Fetching ArgoCD initial admin password (if default secret still exists)..."
kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "⚠️ Default admin secret not found (may have been replaced)."
