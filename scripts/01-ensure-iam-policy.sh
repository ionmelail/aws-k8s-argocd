#!/bin/bash
set -euo pipefail

# Configuration
CLUSTER_NAME="my-cluster"
SERVICE_ACCOUNT="ingress-nginx-controller"
NAMESPACE="ingress-nginx"
POLICY_NAME="AmazonEKSLoadBalancerController"

echo "🔍 Checking if IAM policy $POLICY_NAME exists..."
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "⚠️ Policy not found. Downloading and creating it..."
  curl -s -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://iam-policy.json
  POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)
else
  echo "✅ IAM policy exists: $POLICY_ARN"
fi

echo "⏳ Waiting for IAM policy to become globally available..."
MAX_RETRIES=12
WAIT_TIME=30
for i in $(seq 1 $MAX_RETRIES); do
  if aws iam get-policy --policy-arn "$POLICY_ARN" > /dev/null 2>&1; then
    echo "✅ IAM Policy is now globally available."
    break
  fi
  echo "⏳ Retrying in $WAIT_TIME seconds... (Attempt $i/$MAX_RETRIES)"
  sleep $WAIT_TIME
  WAIT_TIME=$((WAIT_TIME * 2))
done

echo "🔗 Creating service account with IRSA via eksctl..."
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE" \
  --name "$SERVICE_ACCOUNT" \
  --attach-policy-arn "$POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts

echo "🔁 Restarting controller to apply IAM role..."
kubectl rollout restart deployment "$SERVICE_ACCOUNT" -n "$NAMESPACE"

echo "🔍 Verifying IAM role annotation on service account..."
SA_ROLE=$(kubectl get sa "$SERVICE_ACCOUNT" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}')

if [ -z "$SA_ROLE" ]; then
  echo "❌ Service account is missing IAM role annotation!"
  exit 1
fi

echo "✅ IAM role is properly annotated: $SA_ROLE"
echo "✅ IAM policy and IRSA setup completed successfully for $SERVICE_ACCOUNT"
