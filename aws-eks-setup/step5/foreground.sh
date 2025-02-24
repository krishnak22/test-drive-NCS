#!/bin/bash

clear
echo "========================================="
echo "   AWS EKS Cluster Creation Wizard"
echo "========================================="

# List of valid AWS regions
VALID_REGIONS=("us-east-1" "us-east-2" "us-west-1" "us-west-2" "eu-central-1" "eu-west-1" "eu-west-2" "ap-south-1" "ap-northeast-1")

while true; do
    # Step 1.1: Prompt user for inputs
    read -p "Enter Cluster Name: " CLUSTER_NAME
    read -p "Enter AWS Region (e.g., us-east-1): " REGION
    read -p "Enter VPC Private Subnets (comma-separated, e.g., subnet-abc123,subnet-def456): " VPC_SUBNETS

    # Step 1.2: Validate inputs
    if [[ -z "$CLUSTER_NAME" || -z "$REGION" || -z "$VPC_SUBNETS" ]]; then
        echo -e "\n⚠️  Error: All fields are required. Please enter valid values.\n"
        continue  # Restart input process
    fi

    # Validate AWS Region
    if [[ ! " ${VALID_REGIONS[@]} " =~ " ${REGION} " ]]; then
        echo -e "\n⚠️  Error: '$REGION' is not a valid AWS region. Please enter a correct region.\n"
        continue  # Restart input process
    fi

    # Check if the cluster already exists
    if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
        echo -e "\n⚠️  Error: Cluster '$CLUSTER_NAME' already exists in region '$REGION'. Choose a different name.\n"
        continue  # Restart input process
    fi

    # Validate Subnets
    VALID_SUBNETS=true
    for SUBNET in ${VPC_SUBNETS//,/ }; do
        if ! aws ec2 describe-subnets --subnet-ids "$SUBNET" --region "$REGION" >/dev/null 2>&1; then
            echo -e "\n⚠️  Error: Subnet ID '$SUBNET' is invalid or does not exist in region '$REGION'.\n"
            VALID_SUBNETS=false
        fi
    done
    if [ "$VALID_SUBNETS" = false ]; then
        continue  # Restart input process
    fi

    # Confirm user inputs before proceeding
    echo -e "\nYou have entered:"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Region: $REGION"
    echo "VPC Private Subnets: $VPC_SUBNETS"
    read -p "Do you want to proceed? (yes/no): " CONFIRM

    if [[ "$CONFIRM" == "yes" ]]; then
        break  # Exit loop and proceed to Step 2
    else
        echo -e "\nRestarting input process...\n"
    fi
done

# Save inputs to a file for the next script
echo "CLUSTER_NAME=$CLUSTER_NAME" > eks_inputs.env
echo "REGION=$REGION" >> eks_inputs.env
echo "VPC_SUBNETS=$VPC_SUBNETS" >> eks_inputs.env

echo -e "\n✅ Inputs validated successfully! Run './eks_create.sh' to create the cluster."

