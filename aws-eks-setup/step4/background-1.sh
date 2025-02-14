
---

#!/bin/bash

# Step 1: Assume the AWS role (Replace <YOUR_ROLE_ARN> with the actual ARN)
ASSUME_ROLE_OUTPUT=$(aws sts assume-role --role-arn "arn:aws:iam::353502843997:role/ncs-storage-22-jan-prac-NCSOrchestratorRole-jDzPo7jpn5DO" --role-session-name "NCS-Test-Drive")

# Step 2: Extract temporary credentials
AWS_ACCESS_KEY_ID=$(echo $ASSUME_ROLE_OUTPUT | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo $ASSUME_ROLE_OUTPUT | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo $ASSUME_ROLE_OUTPUT | jq -r '.Credentials.SessionToken')

# Step 3: Store the credentials in a temporary file
echo "[default]" > /root/aws_credentials
echo "aws_access_key_id=$AWS_ACCESS_KEY_ID" >> /root/aws_credentials
echo "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY" >> /root/aws_credentials
echo "aws_session_token=$AWS_SESSION_TOKEN" >> /root/aws_credentials


# Step 4: Export credentials as environment variables
export AWS_ACCESS_KEY_ID=$(grep 'aws_access_key_id' /root/aws_credentials | cut -d '=' -f2 | tr -d ' ')
export AWS_SECRET_ACCESS_KEY=$(grep 'aws_secret_access_key' /root/aws_credentials | cut -d '=' -f2 | tr -d ' ')
export AWS_SESSION_TOKEN=$(grep 'aws_session_token' /root/aws_credentials | cut -d '=' -f2 | tr -d ' ')
