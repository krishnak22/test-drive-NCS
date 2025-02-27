source eks_inputs.env
# Get the IAM role ARN associated with the service account
SERVICE_ACCOUNT_ROLE=$(aws eks describe-service-account \
  --name "$SERVICE_ACCOUNT_NAME" \
  -n namespace "$OPERATOR_NAMESPACE"
  --cluster-name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query "serviceAccount.role" --output text)
