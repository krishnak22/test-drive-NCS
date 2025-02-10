#!/bin/bash

ROLE_ARN="arn:aws:iam::353502843997:role/ncs-storage-22-jan-prac-NCSOrchestratorRole-jDzPo7jpn5DO"
SESSION_NAME="KillercodaSession"

echo "🚀 Assuming IAM role..."

# Assume the IAM role and capture credentials
CREDENTIALS=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "$SESSION_NAME" --query "Credentials" --output json)

# Extract credentials
AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r ".AccessKeyId")
AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r ".SecretAccessKey")
AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r ".SessionToken")

# Create an export script for credentials
cat <<EOF > /root/temp_creds.sh
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN
EOF

# Make the credentials script executable
chmod +x /root/temp_creds.sh

# Mark credentials as ready
touch /root/temp_creds_ready

echo "✅ IAM role assumed successfully! Credentials are ready."

