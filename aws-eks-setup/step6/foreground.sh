#!/bin/bash

# Load variables from the saved input file
if [[ ! -f eks_inputs.env ]]; then
    echo "⚠️  Error: eks_inputs.env file not found. Run './eks_input.sh' first."
    exit 1
fi

source eks_inputs.env

echo -e "\n🚀 Starting EKS cluster creation..."
eksctl create cluster --name "$CLUSTER_NAME" --region "$REGION" --vpc-private-subnets "$VPC_SUBNETS"

if [[ $? -eq 0 ]]; then
    echo -e "\n✅ EKS Cluster '$CLUSTER_NAME' created successfully!"
else
    echo -e "\n❌ Error: Failed to create the EKS cluster."
    exit 1
fi

