#!/bin/bash

# Source the eks_inputs.env file to get required variables
source eks_inputs.env

# Paths to your two JSON policy files 
POLICY_FILE_1="/root/bf-policy-1.json"  
POLICY_FILE_2="/root/bf-policy-2.json"  

# Retrieve the IAM role name associated with the service account
ROLE_NAME="$SA_ROLE_NAME"

# Attach the first inline policy to the IAM role using the first policy JSON file
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "test-drive-ncs-bf-policy-1" --policy-document "file://$POLICY_FILE_1"

# Attach the second inline policy to the IAM role using the second policy JSON file
aws iam put-role-policy   --role-name "$ROLE_NAME" --policy-name "test-drive-ncs-bf-policy-2" --policy-document "file://$POLICY_FILE_2"


