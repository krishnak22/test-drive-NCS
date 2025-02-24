#!/bin/bash

# Function to check validation results
check_validation() {
    while [ ! -f validation_result.txt ]; do
        sleep 1
    done
    source validation_result.txt
    rm validation_result.txt
}

# Get user inputs
read -p "Enter Cluster Name: " CLUSTER_NAME
read -p "Enter AWS Region: " REGION
read -p "Enter VPC Private Subnets (comma-separated): " SUBNETS

# Start background validation
./validate.sh "$CLUSTER_NAME" "$REGION" "$SUBNETS" &

# Wait for validation results
check_validation

# Check if validation was successful
if [ "$VALIDATION_STATUS" == "success" ]; then
    echo "Validation successful. Creating EKS cluster..."
    # eksctl create cluster --name "$CLUSTER_NAME" --region "$REGION" --vpc-private-subnets "$SUBNETS"
else
    echo "Validation failed: $VALIDATION_MESSAGE"
    exit 1
fi

