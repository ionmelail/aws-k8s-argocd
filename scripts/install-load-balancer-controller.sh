#!/bin/bash
set -e

echo "🔍 Checking if AWS Load Balancer Controller is installed..."
if ! kubectl get deployment -n kube-system aws-load-balancer-controller > /dev/null 2>&1; then
  echo "🚀 Installing AWS Load Balancer Controller..."

  # Load required variables
  CLUSTER_NAME=my-cluster
  REGION=us-west-2
  VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text --region "$REGION")

  helm repo add eks https://aws.github.io/eks-charts
  helm repo update

  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$REGION \
    --set vpcId=$VPC_ID
else
  echo "✅ AWS Load Balancer Controller already installed."
fi
