#!/bin/bash

ROLE_ARN="arn:aws:iam::353502843997:role/ncs-storage-22-jan-prac-NCSOrchestratorRole-jDzPo7jpn5DO"  
SESSION_NAME="KillercodaSession"

# Assume the IAM role and capture credentials
CREDENTIALS=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "$SESSION_NAME" --query "Credentials" --output json)

# Extract credentials and store them in a file
echo "AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r ".AccessKeyId")" > /test-drive/aws-eks/step4/temp_creds.txt
echo "AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r ".SecretAccessKey")" >> /test-drive/aws-eks/step4/temp_creds.txt
echo "AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r ".SessionToken")" >> /test-drive/aws-eks/step4/temp_creds.txt

# Mark credentials as ready
touch /test-drive/aws-eks/step4/temp_creds_ready

echo "IAM role assumed successfully!"

