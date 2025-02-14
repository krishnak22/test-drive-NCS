
---

### **Background Script (script1.sh)**  
This script will:  
 Assume the pre-configured role  
 Extract temporary credentials  
 Store them in a credentials file  
 Automatically set environment variables  

```sh
#!/bin/bash

# Step 1: Assume the AWS role (Replace <YOUR_ROLE_ARN> with the actual ARN)
ASSUME_ROLE_OUTPUT=$(aws sts assume-role --role-arn "arn:aws:iam::353502843997:role/ncs-storage-22-jan-prac-NCSOrchestratorRole-jDzPo7jpn5DO" --role-session-name "NCS-Test-Drive")

# Step 2: Extract temporary credentials
AWS_ACCESS_KEY_ID=$(echo $ASSUME_ROLE_OUTPUT | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo $ASSUME_ROLE_OUTPUT | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo $ASSUME_ROLE_OUTPUT | jq -r '.Credentials.SessionToken')

# Step 3: Store the credentials in a temporary file
echo "[default]" > /tmp/aws_credentials
echo "aws_access_key_id=$AWS_ACCESS_KEY_ID" >> /tmp/aws_credentials
echo "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY" >> /tmp/aws_credentials
echo "aws_session_token=$AWS_SESSION_TOKEN" >> /tmp/aws_credentials

# Step 4: Export credentials as environment variables
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN

