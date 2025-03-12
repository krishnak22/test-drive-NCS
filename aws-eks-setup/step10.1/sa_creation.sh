#!/bin/bash

# Source the eks_inputs.env file
source eks_inputs.env

# Create the IAM service account
eksctl create iamserviceaccount --cluster "$CLUSTER_NAME" --region "$REGION" --name ncs-infra-sa-new-2 --namespace ncs-infra-deployment-operator-system --attach-policy-arn arn:aws:iam::353502843997:policy/test-drive-ncs-bf-op-policy-1 --approve


