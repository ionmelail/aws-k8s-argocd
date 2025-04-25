#!/bin/bash
set -euo pipefail

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
  curl -fsSL -o iam-policy-nginx.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

  echo "🧪 Validating NGINX policy JSON..."
  if [ ! -s iam-policy-nginx.json ]; then
    echo "❌ Downloaded NGINX policy file is empty. Aborting."
    exit 1
  fi
  jq . iam-policy-nginx.json > /dev/null || { echo "❌ Malformed NGINX policy JSON. Aborting."; exit 1; }

  aws iam create-policy \
    --policy-name "$POLICY_NAME_NGINX" \
    --policy-document file://iam-policy-nginx.json

  POLICY_ARN_NGINX=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME_NGINX'].Arn" --output text)
else
  echo "✅ NGINX IAM policy exists: $POLICY_ARN_NGINX"
fi

echo "🔗 Creating IRSA for NGINX Ingress..."
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
  curl -fsSL -o iam-policy-guardduty.json https://raw.githubusercontent.com/aws/amazon-guardduty-eks-runtime-monitoring/main/deployment/IAMPolicy.json

  echo "🧪 Validating GuardDuty policy JSON..."
  if [ ! -s iam-policy-guardduty.json ]; then
    echo "❌ Downloaded GuardDuty policy file is empty. Aborting."
    exit 1
  fi
  jq . iam-policy-guardduty.json > /dev/null || { echo "❌ Malformed GuardDuty policy JSON. Aborting."; exit 1; }

  aws iam create-policy \
    --policy-name "$POLICY_NAME_GD" \
    --policy-document file://iam-policy-guardduty.json

  POLICY_ARN_GD=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME_GD'].Arn" --output text)
else
  echo "✅ GuardDuty IAM policy exists: $POLICY_ARN_GD"
fi

echo "🔗 Creating IRSA for GuardDuty Runtime Monitoring..."
eksctl create iamserviceaccount \
  --cluster "$CLUSTER_NAME" \
  --namespace "$NAMESPACE_GD" \
  --name "$SERVICE_ACCOUNT_GD" \
  --attach-policy-arn "$POLICY_ARN_GD" \
  --approve \
  --override-existing-serviceaccounts

#####################################
# ✅ Final Validation
#####################################
echo "🔍 Verifying IAM role annotations..."

SA_ROLE_NGINX=$(kubectl get sa "$SERVICE_ACCOUNT_NGINX" -n "$NAMESPACE_NGINX" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' || true)
SA_ROLE_GD=$(kubectl get sa "$SERVICE_ACCOUNT_GD" -n "$NAMESPACE_GD" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' || true)

if [ -z "$SA_ROLE_NGINX" ]; then
  echo "❌ Missing IAM annotation on NGINX service account."
  exit 1
fi

if [ -z "$SA_ROLE_GD" ]; then
  echo "❌ Missing IAM annotation on GuardDuty service account."
  exit 1
fi

echo "✅ IRSA setup complete:"
echo "  - NGINX:     $SERVICE_ACCOUNT_NGINX (namespace: $NAMESPACE_NGINX)"
echo "      ↳ Role:  $SA_ROLE_NGINX"
echo "  - GuardDuty: $SERVICE_ACCOUNT_GD (namespace: $NAMESPACE_GD)"
echo "      ↳ Role:  $SA_ROLE_GD"

echo "👉 Reminder: Assign the GuardDuty IAM role in the EKS Console:"
echo "   EKS > Add-ons > GuardDuty > Edit > Assign IAM role"
