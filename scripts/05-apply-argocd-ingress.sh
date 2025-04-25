
# Apply ArgoCD Ingress
echo "📦 Applying ArgoCD Ingress resource..."
kubectl apply -f argocd/argocd-server-ingress.yaml || {
  echo "❌ Failed to apply ArgoCD Ingress. Exiting."
  exit 1
}

echo "✅ ArgoCD is now accessible via:"
echo "🔗 https://$LB_HOSTNAME"
