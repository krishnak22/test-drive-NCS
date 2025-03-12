# Assume the role and capture credentials
CREDENTIALS=$(aws sts assume-role --role-arn "arn:aws:iam::353502843997:role/ncs-storage-22-jan-prac-NCSOrchestratorRole-jDzPo7jpn5DO" --role-session-name "NCS-Test-Drive" --query 'Credentials' --output json)

# Extract individual values
AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.SessionToken')

# Export credentials
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

# Confirm export
echo "AWS credentials have been set in the environment."
