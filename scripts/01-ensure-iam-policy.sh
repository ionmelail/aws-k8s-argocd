#####################################
# 2️⃣ GuardDuty Runtime Monitoring Setup
#####################################
SERVICE_ACCOUNT_GD="guardduty-agent"
NAMESPACE_GD="amazon-guardduty"
POLICY_NAME_GD="AmazonGuardDutyEKSRuntimeMonitoringPolicy"
LOCAL_POLICY_PATH_GD="iam/iam-policy.json"

echo "🔍 Checking IAM policy for GuardDuty..."
POLICY_ARN_GD=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME_GD'].Arn" --output text)

if [ -z "$POLICY_ARN_GD" ]; then
  echo "📄 GuardDuty policy not found in IAM. Using local file: $LOCAL_POLICY_PATH_GD"

  echo "🧪 Validating local policy JSON..."
  if ! jq . "$LOCAL_POLICY_PATH_GD" > /dev/null 2>&1; then
    echo "❌ Malformed JSON in $LOCAL_POLICY_PATH_GD. Aborting!"
    exit 1
  fi

  echo "📥 Creating IAM policy for GuardDuty from local file..."
  aws iam create-policy \
    --policy-name "$POLICY_NAME_GD" \
    --policy-document "file://$LOCAL_POLICY_PATH_GD"

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
