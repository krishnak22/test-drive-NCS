#!/bin/bash

ROLE_ARN="arn:aws:iam::123456789012:role/MyRole"  # Replace with your actual Role ARN
SESSION_NAME="KillercodaSession"

# Assume the IAM role and capture credentials
CREDENTIALS=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "$SESSION_NAME" --query "Credentials" --output json)

# Extract and export the credentials
export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r ".AccessKeyId")
export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r ".SecretAccessKey")
export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r ".SessionToken")

echo "IAM role assumed successfully!"

