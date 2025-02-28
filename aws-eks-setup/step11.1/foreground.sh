#!/bin/bash

# Source the eks_inputs.env file
source eks_inputs.env

# Create the IAM service account
eksctl create iamserviceaccount --cluster "$CLUSTER_NAME" --region "$REGION" --name ncs-infra-sa-new-2 --namespace ncs-infra-deployment-operator-system --approve

# Add service account name and namespace to eks_inputs.env
echo "SERVICE_ACCOUNT_NAME=ncs-infra-sa-new-2" >> eks_inputs.env
echo "OPERATOR_NAMESPACE=ncs-infra-deployment-operator-system" >> eks_inputs.env

# Retrieve the role name and ARN of the service account
ROLE_NAME=$(aws iam list-roles --query "Roles[?RoleName=='eksctl-${CLUSTER_NAME}-cluster-ServiceAccount-ncs-infra-sa-new-2'].RoleName" --output text)
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.Arn" --output text)

# Add role name and ARN to eks_inputs.env
echo "SERVICE_ACCOUNT_ROLE_NAME=$ROLE_NAME" >> eks_inputs.env
echo "SERVICE_ACCOUNT_ROLE_ARN=$ROLE_ARN" >> eks_inputs.env

echo "Service account name, namespace, role name, and role ARN have been added to eks_inputs.env"

