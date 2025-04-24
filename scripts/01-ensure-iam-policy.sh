#!/bin/bash
set -euo pipefail

CLUSTER_NAME="your-cluster-name"
SERVICE_ACCOUNT="ingress-nginx-controller"
NAMESPACE="ingress-nginx"
POLICY_NAME="AmazonEKSLoadBalancerController"

echo "🔍 Checking if IAM policy $POLICY_NAME exists..."
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "⚠️ Policy not found. Downloading and creating it..."
  curl -s -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://iam_policy.json
  POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)
else
  echo "✅ Policy already exists: $POLICY_ARN"
fi

echo "⏳ Waiting for policy to become globally available..."
MAX_RETRIES=12
WAIT_TIME=30
for i in $(seq 1 $MAX_RETRIES); do
  if aws iam get-policy --policy-arn "$POLICY_ARN" > /dev/null 2>&1; then
    echo "✅ Policy is now available globally."
    break
  fi
  echo "⏳ Retrying in $WAIT_TIME seconds... (Attempt $i/$MAX_RETRIES)"
  sleep $WAIT_TIME
  WAIT_TIME=$((WAIT_TIME * 2))
done

echo "🔗 Creating service account with IRSA..."
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE" \
  --name "$SERVICE_ACCOUNT" \
  --attach-policy-arn "$POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts

echo "🔁 Restarting controller to apply new IAM role..."
kubectl rollout restart deployment "$SERVICE_ACCOUNT" -n "$NAMESPACE"

echo "✅ IRSA setup complete for $SERVICE_ACCOUNT with policy: $POLICY_NAME"
