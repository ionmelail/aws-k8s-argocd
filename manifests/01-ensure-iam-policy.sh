#!/bin/bash
set -e
POLICY_NAME="AmazonEKSLoadBalancerController"
REGION="us-west-2"

echo "🔍 Checking IAM policy..."
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)
if [ -z "$POLICY_ARN" ]; then
  echo "⚠️ IAM Policy not found! Creating..."
  curl -s -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  aws iam create-policy --policy-name $POLICY_NAME --policy-document file://iam_policy.json
else
  echo "✅ IAM Policy already exists: $POLICY_ARN"
fi
