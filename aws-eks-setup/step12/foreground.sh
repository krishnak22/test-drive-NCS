#!/bin/bash

# Function to validate a numeric input
is_numeric() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Function to validate if a CIDR is valid
is_valid_cidr() {
    local cidr=$1
    if [[ "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate NODE_COUNT between 1 and 15
is_valid_node_count() {
    if [[ "$1" -ge 1 && "$1" -le 15 ]]; then
        return 0
    else
        return 1
    fi
}

# Print a message to prompt the user for input
echo "ENTER THE FOLLOWING DETAILS"

# Ask the user for the values and store them in variables
while true; do
    read -p "NODE_COUNT (between 1 and 15): " NODE_COUNT
    if is_numeric "$NODE_COUNT" && is_valid_node_count "$NODE_COUNT"; then
        break
    else
        echo "Invalid input for NODE_COUNT. Please enter a number between 1 and 15."
    fi
done

while true; do
    read -p "AVAILABILITY_ZONE: " AVAILABILITY_ZONE
    if [[ -n "$AVAILABILITY_ZONE" ]]; then
        break
    else
        echo "AVAILABILITY_ZONE cannot be empty. Please enter a valid value."
    fi
done

while true; do
    read -p "INSTANCE_TYPE: " INSTANCE_TYPE
    if [[ -n "$INSTANCE_TYPE" ]]; then
        break
    else
        echo "INSTANCE_TYPE cannot be empty. Please enter a valid value."
    fi
done

while true; do
    read -p "AMI_TYPE: " AMI_TYPE
    if [[ "$AMI_TYPE" == "AL2" || "$AMI_TYPE" == "Ubuntu" ]]; then
        break
    else
        echo "Invalid input for AMI_TYPE. Please enter either 'AL2' or 'Ubuntu'."
    fi
done

while true; do
    read -p "AMI_RELEASE_VERSION: " AMI_RELEASE_VERSION
    if [[ -n "$AMI_RELEASE_VERSION" ]]; then
        break
    else
        echo "AMI_RELEASE_VERSION cannot be empty. Please enter a valid value."
    fi
done

while true; do
    read -p "SSH-KEY-PAIR: " SSH_KEY_PAIR
    if [[ -n "$SSH_KEY_PAIR" ]]; then
        # Check if the SSH key exists in AWS (using AWS CLI)
        if aws ec2 describe-key-pairs --key-name "$SSH_KEY_PAIR" >/dev/null 2>&1; then
            break
        else
            echo "SSH key '$SSH_KEY_PAIR' not found in AWS. Please enter a valid SSH key pair."
        fi
    else
        echo "SSH-KEY-PAIR cannot be empty. Please enter a valid value."
    fi
done

while true; do
    read -p "SUBNET_CIDR: " SUBNET_CIDR
    if is_valid_cidr "$SUBNET_CIDR"; then
        break
    else
        echo "Invalid CIDR format for SUBNET_CIDR. Please enter a valid CIDR block (e.g., 10.0.0.0/24)."
    fi
done

while true; do
    read -p "NCS_CLUSTER_NAME: " NCS_CLUSTER_NAME
    if [[ -n "$NCS_CLUSTER_NAME" ]]; then
        break
    else
        echo "NCS_CLUSTER_NAME cannot be empty. Please enter a valid value."
    fi
done

while true; do
    read -p "AOS_SUBNET_CIDR: " AOS_SUBNET_CIDR
    if is_valid_cidr "$AOS_SUBNET_CIDR"; then
        break
    else
        echo "Invalid CIDR format for AOS_SUBNET_CIDR. Please enter a valid CIDR block (e.g., 10.1.0.0/24)."
    fi
done

while true; do
    read -p "VERSION: " VERSION
    if [[ -n "$VERSION" ]]; then
        break
    else
        echo "VERSION cannot be empty. Please enter a valid value."
    fi
done

# Append the values to the eks_inputs.env file
echo "NODE_COUNT=$NODE_COUNT" >> eks_inputs.env
echo "AVAILABILITY_ZONE=$AVAILABILITY_ZONE" >> eks_inputs.env
echo "INSTANCE_TYPE=$INSTANCE_TYPE" >> eks_inputs.env
echo "AMI_TYPE=$AMI_TYPE" >> eks_inputs.env
echo "AMI_RELEASE_VERSION=$AMI_RELEASE_VERSION" >> eks_inputs.env
echo "SSH_KEY_PAIR=$SSH_KEY_PAIR" >> eks_inputs.env
echo "SUBNET_CIDR=$SUBNET_CIDR" >> eks_inputs.env
echo "NCS_CLUSTER_NAME=$NCS_CLUSTER_NAME" >> eks_inputs.env
echo "AOS_SUBNET_CIDR=$AOS_SUBNET_CIDR" >> eks_inputs.env
echo "VERSION=$VERSION" >> eks_inputs.env

echo "Values have been successfully added to eks_inputs.env!"

