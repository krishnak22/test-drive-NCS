#!/bin/bash

# Assume AWS role and capture output
aws_assume_role_id=$(aws sts assume-role --role-arn "arn:aws:iam::36747643997:role/ncsn5DO" --role-session-name "MySession" 2>> /tmp/aws-error.log)

# Debugging
echo "Assumed Role Output: $aws_assume_role_id" | tee -a /tmp/debug.log

# Save to a file
echo "$aws_assume_role_id" > /home/ubuntu/aws-cred

# Persist the variable for future sessions
echo "export aws_assume_role_id='$aws_assume_role_id'" >> /home/ubuntu/.profile

# Debugging: Check if aws_assume_role_id is set
echo "aws_assume_role_id successfully set!" | tee -a /tmp/debug.log

