#!/bin/bash

ENV_FILE="eks_inputs.env"

clear

# List of valid AWS regions
VALID_REGIONS=("us-east-1" "us-east-2" "us-west-1" "us-west-2" "eu-central-1" "eu-west-1" "eu-west-2" "ap-south-1" "ap-northeast-1")

# Function to validate cluster name
validate_cluster_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
        echo "Error: Cluster name must contain only lowercase letters, numbers, and hyphens (-), and must start and end with a letter or number."
        return 1
    fi
    if [[ ${#name} -lt 1 || ${#name} -gt 100 ]]; then
        echo "Error: Cluster name must be between 1 and 100 characters long."
        return 1
    fi
    return 0
}

# Step 1: Take and validate Cluster Name
while true; do
    read -p "Enter Cluster Name: " CLUSTER_NAME
    if [[ -z "$CLUSTER_NAME" ]]; then
        echo "Error: Cluster Name cannot be empty."
        continue
    fi
    if validate_cluster_name "$CLUSTER_NAME"; then
        break
    fi
done

# Step 2: Take and validate AWS Region
while true; do
    read -p "Enter AWS Region: " REGION
    if [[ -z "$REGION" ]]; then
        echo "Error: AWS Region cannot be empty."
        continue
    fi
    if [[ " ${VALID_REGIONS[@]} " =~ " ${REGION} " ]]; then
        break
    else
        echo "Error: '$REGION' is not a valid AWS region."
    fi
done

# Step 3: Take and validate VPC Subnets (skip validation for now to let the user enter values)
while true; do
    read -p "Enter VPC Private Subnets (comma-separated): " VPC_SUBNETS
    if [[ -z "$VPC_SUBNETS" ]]; then
        echo "Error: VPC Subnets cannot be empty."
        continue
    fi
    # For now, we're skipping subnet validation to allow input even if invalid.
    break
done

# Step 4: Take the primary_owner value
while true; do
    read -p "Enter the primary owner value: " PRIMARY_OWNER
    if [[ -z "$PRIMARY_OWNER" ]]; then
        echo "Error: Primary_Owner field cannot be empty."
        continue
    fi
    break  # Exit the loop once a valid input is received
done

# Confirm user inputs before proceeding
echo -e "\nYou have entered:"
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "VPC Private Subnets: $VPC_SUBNETS"
echo "Primary_Owner: $PRIMARY_OWNER"
read -p "Do you want to proceed? (yes/no): " CONFIRM

if [[ "$CONFIRM" == "yes" ]]; then
    # Store validated inputs in env file
    ENV_FILE="/root/eks_inputs.env"
    echo "CLUSTER_NAME=$CLUSTER_NAME" > "$ENV_FILE"
    echo "REGION=$REGION" >> "$ENV_FILE"
    echo "VPC_SUBNETS=$VPC_SUBNETS" >> "$ENV_FILE"
    echo "PRIMARY_OWNER=$PRIMARY_OWNER" >> "$ENV_FILE"
    echo "Inputs saved to $ENV_FILE"
else
    echo "Operation canceled."
fi

