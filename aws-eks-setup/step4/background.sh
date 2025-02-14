#!/bin/bash

aws_assume_role_id=$(/root/aws-1 sts assume-role --role-arn "arn:aws:iam::353502843997:role/ncs-storage-22-jan-prac-NCSOrchestratorRole-jDzPo7jpn5DO" --role-session-name "MySession")

# Debug: Print output to ensure it's captured
echo "Assumed Role Output: $aws_assume_role_id" >> /tmp/debug.log

# Save it to a file
echo "$aws_assume_role_id" > /home/ubuntu/aws-cred

# Export so it's available in the current session
echo "export aws_assume_role_id='$aws_assume_role_id'" >> /home/ubuntu/.bashrc
source /home/ubuntu/.profile

