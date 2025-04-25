#!/bin/bash
set -euo pipefail

# Common config
CLUSTER_NAME="my-cluster"

#####################################
# 1️⃣ NGINX Ingress Controller Setup
#####################################
SERVICE_ACCOUNT_NGINX="ingress-nginx-controller"
NAMESPACE_NGINX="ingress-nginx"
POLICY_NAME_NGINX="AmazonEKSLoadBalancerController"

echo "🔍 Checking IAM policy for NGINX..."
POLICY_ARN_NGINX=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME_NGINX'].Arn" --output text)

if [ -z "$POLICY_ARN_NGINX" ]; then
  echo "⚠️ NGINX policy not found. Creating it..."
  curl -s -o iam-policy-nginx.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  aws iam create-policy \
    --policy-name "$POLICY_NAME_NGINX" \
    --policy-document file://iam-policy-nginx.json
  POLICY_ARN_NGINX=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME_NGINX'].Arn" --output text)
fi

echo "🔗 Setting up IRSA for NGINX Ingress..."
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE_NGINX" \
  --name "$SERVICE_ACCOUNT_NGINX" \
  --attach-policy-arn "$POLICY_ARN_NGINX" \
  --approve \
  --override-existing-serviceaccounts

#####################################
# 2️⃣ GuardDuty Runtime Monitoring Setup
#####################################
SERVICE_ACCOUNT_GD="guardduty-agent"
NAMESPACE_GD="amazon-guardduty"
POLICY_NAME_GD="AmazonGuardDutyEKSRuntimeMonitoringPolicy"

echo "🔍 Checking IAM policy for GuardDuty..."
POLICY_ARN_GD=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME_GD'].Arn" --output text)

if [ -z "$POLICY_ARN_GD" ]; then
  echo "⚠️ GuardDuty policy not found. Downloading and creating..."
  curl -sSL -o iam-policy-guardduty.json https://raw.githubusercontent.com/aws/amazon-guardduty-eks-runtime-monitoring/main/deployment/IAMPolicy.json

  echo "🧪 Validating policy JSON..."
  if ! jq . iam-policy-guardduty.json > /dev/null 2>&1; then
    echo "❌ Malformed JSON in policy. Aborting!"
    exit 1
  fi

  aws iam create-policy \
    --policy-name "$POLICY_NAME_GD" \
    --policy-document file://iam-policy-guardduty.json
  POLICY_ARN_GD=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME_GD'].Arn" --output text)
fi

echo "🔗 Setting up IRSA for GuardDuty..."
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE_GD" \
  --name "$SERVICE_ACCOUNT_GD" \
  --attach-policy-arn "$POLICY_ARN_GD" \
  --approve \
  --override-existing-serviceaccounts

echo "✅ IRSA setup complete for:"
echo "  - NGINX:     $SERVICE_ACCOUNT_NGINX (namespace: $NAMESPACE_NGINX)"
echo "  - GuardDuty: $SERVICE_ACCOUNT_GD (namespace: $NAMESPACE_GD)"

echo "👉 Please assign the GuardDuty IAM role manually in the EKS Console → Add-ons → Edit → Select IAM Role"
