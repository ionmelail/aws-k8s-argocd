#!/bin/bash
set -euo pipefail

# Configuration
CLUSTER_NAME="my-cluster"
NAMESPACE="ingress-nginx"
SERVICE_ACCOUNT="ingress-nginx-controller"
POLICY_NAME="AmazonEKSLoadBalancerController"
POLICY_FILE="iam-policy-nginx.json"

echo "🔍 Checking if IAM policy '$POLICY_NAME' exists..."
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "⚠️ Policy not found. Downloading and creating it..."
  curl -s -o $POLICY_FILE https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

  echo "🧪 Validating policy JSON..."
  if ! jq . "$POLICY_FILE" > /dev/null 2>&1; then
    echo "❌ Malformed policy JSON. Aborting!"
    exit 1
  fi

  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://$POLICY_FILE

  POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)
else
  echo "✅ IAM policy exists: $POLICY_ARN"
fi

echo "⏳ Waiting for IAM policy to be globally available..."
MAX_RETRIES=12
WAIT_TIME=30
for i in $(seq 1 $MAX_RETRIES); do
  if aws iam get-policy --policy-arn "$POLICY_ARN" > /dev/null 2>&1; then
    echo "✅ IAM Policy is now globally available."
    break
  fi
  echo "⏳ Waiting $WAIT_TIME seconds... (Attempt $i/$MAX_RETRIES)"
  sleep $WAIT_TIME
  WAIT_TIME=$((WAIT_TIME * 2))
done

echo "🔗 Creating or updating IRSA service account with eksctl..."
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE" \
  --name "$SERVICE_ACCOUNT" \
  --attach-policy-arn "$POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts

echo "🔍 Verifying IAM role annotation on service account..."
SA_ROLE=$(kubectl get sa "$SERVICE_ACCOUNT" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' || true)

if [ -z "$SA_ROLE" ]; then
  echo "❌ Service account is missing IAM role annotation!"
  exit 1
fi

echo "✅ IAM role is correctly annotated: $SA_ROLE"
echo "✅ IAM policy and IRSA setup completed successfully for NGINX Ingress Controller."
