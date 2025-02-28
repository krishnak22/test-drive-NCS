#!/bin/bash

# Log function for error messages
log_message() {
    echo "$1"
}

# Function to validate CIDR format
validate_cidr() {
    local cidr="$1"
    if [[ ! "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 1
    fi
    return 0
}

while true; do
    # Step 1.1: Prompt user for inputs
    read -p "Enter NODE_COUNT: " NODE_COUNT
    read -p "Enter AVAILABILITY_ZONE: " AVAILABILITY_ZONE
    read -p "Enter INSTANCE_TYPE: " INSTANCE_TYPE
    read -p "Enter AMI_TYPE: " AMI_TYPE
    read -p "Enter AMI_RELEASE_VERSION: " AMI_RELEASE_VERSION
    read -p "Enter SSH_KEY_PAIR: " SSH_KEY_PAIR
    read -p "Enter SUBNET_CIDR: " SUBNET_CIDR
    read -p "Enter NCS_CLUSTER_NAME: " NCS_CLUSTER_NAME
    read -p "Enter AOS_SUBNET_CIDR: " AOS_SUBNET_CIDR
    read -p "Enter VERSION: " VERSION

    # Step 1.2: Validate inputs
    if [[ -z "$NODE_COUNT" || -z "$AVAILABILITY_ZONE" || -z "$INSTANCE_TYPE" || -z "$AMI_TYPE" || -z "$AMI_RELEASE_VERSION" || -z "$SSH_KEY_PAIR" || -z "$SUBNET_CIDR" || -z "$NCS_CLUSTER_NAME" || -z "$AOS_SUBNET_CIDR" || -z "$VERSION" ]]; then
        log_message "Error: All fields are required. Please enter valid values."
        continue
    fi

    # Step 1.3: Validate SUBNET_CIDR and AOS_SUBNET_CIDR (CIDR format check)
    if ! validate_cidr "$SUBNET_CIDR"; then
        log_message "Error: Invalid SUBNET_CIDR format. Please enter a valid CIDR (e.g., 192.168.0.0/24)."
        continue
    fi

    if ! validate_cidr "$AOS_SUBNET_CIDR"; then
        log_message "Error: Invalid AOS_SUBNET_CIDR format. Please enter a valid CIDR (e.g., 192.168.0.0/24)."
        continue
    fi

    # Step 1.4: Store inputs in /root/eks_inputs.env
    echo "NODE_COUNT=$NODE_COUNT" >> /root/eks_inputs.env
    echo "AVAILABILITY_ZONE=$AVAILABILITY_ZONE" >> /root/eks_inputs.env
    echo "INSTANCE_TYPE=$INSTANCE_TYPE" >> /root/eks_inputs.env
    echo "AMI_TYPE=$AMI_TYPE" >> /root/eks_inputs.env
    echo "AMI_RELEASE_VERSION=$AMI_RELEASE_VERSION" >> /root/eks_inputs.env
    echo "SSH_KEY_PAIR=$SSH_KEY_PAIR" >> /root/eks_inputs.env
    echo "SUBNET_CIDR=$SUBNET_CIDR" >> /root/eks_inputs.env
    echo "NCS_CLUSTER_NAME=$NCS_CLUSTER_NAME" >> /root/eks_inputs.env
    echo "AOS_SUBNET_CIDR=$AOS_SUBNET_CIDR" >> /root/eks_inputs.env
    echo "VERSION=$VERSION" >> /root/eks_inputs.env

    # Step 1.5: Confirm success and break out of loop
    log_message "All inputs have been successfully collected and saved in /root/eks_inputs.env"
    break
done

