#!/bin/bash

source eks_inputs.env

echo "SERVICE_ACCOUNT_NAME=ncs-infra-sa-new-2" >>/root/eks_inputs.env
echo "SERVICE_ACCOUNT_NAMESPACE=ncs-infra-deployment-operator-system" >> /root/eks_inputs.env


source eks_inputs.env
SA_ROLE_NAME=$(kubectl get sa "$SERVICE_ACCOUNT_NAME" -n "$SERVICE_ACCOUNT_NAMESPACE" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' | awk -F'/' '{print $NF}')
echo "SA_ROLE_NAME=$SA_ROLE_NAME" >> /root/eks_inputs.env
source eks_inputs.env
SA_ROLE_ARN=$(kubectl get sa $SERVICE_ACCOUNT_NAME -n $SERVICE_ACCOUNT_NAMESPACE -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}')
echo "SA_ROLE_ARN=$SA_ROLE_ARN" >> /root/eks_inputs.env

source eks_inputs.env
POLICY_FILE_1="/root/bf-policy-1.json"  
POLICY_FILE_2="/root/bf-policy-2.json"  

ROLE_NAME="$SA_ROLE_NAME"

# Attach the first inline policy to the IAM role using the first policy JSON file
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "test-drive-ncs-bf-policy-1" --policy-document "file://$POLICY_FILE_1"

# Attach the second inline policy to the IAM role using the second policy JSON file
aws iam put-role-policy   --role-name "$ROLE_NAME" --policy-name "test-drive-ncs-bf-policy-2" --policy-document "file://$POLICY_FILE_2"

source eks_inputs.env
eksctl create iamidentitymapping --cluster $CLUSTER_NAME --region=$REGION --arn $ROLE_ARN --group system:masters
