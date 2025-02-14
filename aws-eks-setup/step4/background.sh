# Step 1: Assume the AWS role
ASSUME_ROLE_OUTPUT=$(aws sts assume-role --role-arn "arn:aws:iam::353502843997:role/ncs-storage-22-jan-prac-NCSOrchestratorRole-jDzPo7jpn5DO" --role-session-name "NCS-Test-Drive" 2>/tmp/aws_error.log)

# Debug: Check if AWS Assume Role command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to assume role. Check /tmp/aws_error.log for details."
    exit 1
fi

# Step 2: Extract temporary credentials safely
AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')


# Step 3: Store the credentials in a temporary file
cat > /root/aws_credentials <<EOF
[default]
aws_access_key_id=$AWS_ACCESS_KEY_ID
aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
aws_session_token=$AWS_SESSION_TOKEN
EOF

# Step 4: Export credentials as environment variables
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
export AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"


echo "Run the given command.""
