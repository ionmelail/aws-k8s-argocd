#!/bin/bash

# Fetch the external IP of the NGINX Ingress Controller
EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Check if an external IP is found
if [[ -z "$EXTERNAL_IP" ]]; then
  echo "❌ Failed to retrieve the external IP of the NGINX Ingress Controller."
  exit 1
fi

echo "✅ External IP of NGINX Ingress Controller: $EXTERNAL_IP"

# Define the path to the Ingress YAML file
INGRESS_YAML="argocd/argocd-server-ingress.yaml"

# Create or overwrite the YAML file with the external IP
cat <<EOF > "$INGRESS_YAML"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"  # Set to "true" if using HTTPS
spec:
  rules:
  - host: "$EXTERNAL_IP"  # Using the external IP of the NGINX Ingress Controller
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80  # Adjust to your service port if it's different
EOF

echo "✅ The Ingress YAML file has been updated with the external IP: $EXTERNAL_IP"

# Apply the updated Ingress resource
kubectl apply -f "$INGRESS_YAML"

echo "✅ Ingress applied successfully. You can access ArgoCD at http://$EXTERNAL_IP"
