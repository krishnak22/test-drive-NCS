#!/bin/bash

# Source the eks_inputs.env file
source eks_inputs.env

# Create the IAM service account
eksctl create iamserviceaccount --cluster "$CLUSTER_NAME" --region "$REGION" --name ncs-infra-sa-new-2 --namespace ncs-infra-deployment-operator-system --attach-policy-arn arn:aws:iam::353502843997:policy/test-drive-ncs-bf-op-policy-1 --approve

# Add service account name and namespace to eks_inputs.env
echo "SERVICE_ACCOUNT_NAME=ncs-infra-sa-new-2" >>/root/eks_inputs.env
echo "OPERATOR_NAMESPACE=ncs-infra-deployment-operator-system" >> /root/eks_inputs.env

# Retrieve the role name and ARN of the service account
SA_ROLE_NAME=$(kubectl get sa "$SERVICE_ACCOUNT_NAME" -n "$SERVICE_ACCOUNT_NAMESPACE" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' | awk -F'/' '{print $NF}')
echo "SA_ROLE_NAME=$SA_ROLE_NAME" >> /root/eks_inputs.env

SA_ROLE_ARN=$(kubectl get sa $SERVICE_ACCOUNT_NAME -n $SERVICE_ACCOUNT_NAMESPACE -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}')
echo "SA_ROLE_ARN=$SA_ROLE_ARN" >> /root/eks_inputs.env

