#!/bin/bash

echo "Starting AWS Assume Role script..." | tee -a /tmp/aws_script.log

# Step 1: Assume the AWS role
ASSUME_ROLE_OUTPUT=$(aws sts assume-role --role-arn "arn:aws:iam::353502843997:role/ncs-storage-22-jan-prac-NCSOrchestratorRole-jDzPo7jpn5DO" --role-session-name "NCS-Test-Drive")

# Step 2: Storing the ASSUME_ROLE_OUTPUT
echo "$ASSUME_ROLE_OUTPUT" | sudo tee /root/aws-cred >dev/null

# Read AWS credentials from the file
AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' /root/aws-cred)
AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' /root/aws-cred)
AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' /root/aws-cred)

# Export the credentials as environment variables
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

# Verify that the credentials have been set
echo "AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID"
echo "AWS_SECRET_ACCESS_KEY: [HIDDEN]"
echo "AWS_SESSION_TOKEN: [HIDDEN]"
