#!/bin/bash
clear
echo "========================================="
echo "   AWS EKS Cluster Creation Wizard"
echo "========================================="

while true; do
    # Step 1.1: Prompt user for inputs
    read -p "Enter Cluster Name: " CLUSTER_NAME
    read -p "Enter AWS Region (e.g., us-east-1): " REGION
    read -p "Enter VPC Private Subnets (comma-separated, e.g., subnet-abc123,subnet-def456): " VPC_SUBNETS

    # Step 1.2: Validate inputs
    if [[ -z "$CLUSTER_NAME" || -z "$REGION" || -z "$VPC_SUBNETS" ]]; then
        echo -e "\n⚠️  Error: All fields are required. Please enter valid values.\n"
        continue  # Go back to Step 1.1
    fi

    # Check if the cluster already exists
    if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
        echo -e "\n⚠️  Error: Cluster '$CLUSTER_NAME' already exists in region '$REGION'. Choose a different name.\n"
        continue  # Go back to Step 1.1
    fi

    # Confirm user inputs before proceeding
    echo -e "\nYou have entered:"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Region: $REGION"
    echo "VPC Private Subnets: $VPC_SUBNETS"
    read -p "Do you want to proceed? (yes/no): " CONFIRM

    if [[ "$CONFIRM" == "yes" ]]; then
        break  # Proceed to cluster creation
    else
        echo -e "\nRestarting input process...\n"
    fi
done

# Step 1.3.2: Execute EKS cluster creation
echo -e "\n🚀 Starting EKS cluster creation...\n"
eksctl create cluster --name "$CLUSTER_NAME" --region "$REGION" --vpc-private-subnets "$VPC_SUBNETS"

if [[ $? -eq 0 ]]; then
    echo -e "\n✅ EKS Cluster '$CLUSTER_NAME' created successfully!"
else
    echo -e "\n❌ Error: Failed to create the EKS cluster."
    exit 1
fi

