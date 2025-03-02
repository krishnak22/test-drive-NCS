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
    # Step 1.1: Prompt user for inputs (Ensuring each input is received properly)
    while [[ -z "$NODE_COUNT" ]]; do
        read -r -p "Enter NODE_COUNT: " NODE_COUNT
    done
    
    while [[ -z "$AVAILABILITY_ZONE" ]]; do
        read -r -p "Enter AVAILABILITY_ZONE: " AVAILABILITY_ZONE
    done

    while [[ -z "$INSTANCE_TYPE" ]]; do
        read -r -p "Enter INSTANCE_TYPE: " INSTANCE_TYPE
    done

    while [[ -z "$AMI_TYPE" ]]; do
        read -r -p "Enter AMI_TYPE: " AMI_TYPE
    done

    while [[ -z "$AMI_RELEASE_VERSION" ]]; do
        read -r -p "Enter AMI_RELEASE_VERSION: " AMI_RELEASE_VERSION
    done

    while [[ -z "$SSH_KEY_PAIR" ]]; do
        read -r -p "Enter SSH_KEY_PAIR: " SSH_KEY_PAIR
    done

    while [[ -z "$SUBNET_CIDR" ]]; do
        read -r -p "Enter SUBNET_CIDR: " SUBNET_CIDR
    done

    while [[ -z "$NCS_CLUSTER_NAME" ]]; do
        read -r -p "Enter NCS_CLUSTER_NAME: " NCS_CLUSTER_NAME
    done

    while [[ -z "$AOS_SUBNET_CIDR" ]]; do
        read -r -p "Enter AOS_SUBNET_CIDR: " AOS_SUBNET_CIDR
    done

    while [[ -z "$VERSION" ]]; do
        read -r -p "Enter VERSION: " VERSION
    done

    # Step 1.2: Validate CIDR formats
    if ! validate_cidr "$SUBNET_CIDR"; then
        log_message "Error: Invalid SUBNET_CIDR format. Please enter a valid CIDR (e.g., 192.168.0.0/24)."
        continue
    fi

    if ! validate_cidr "$AOS_SUBNET_CIDR"; then
        log_message "Error: Invalid AOS_SUBNET_CIDR format. Please enter a valid CIDR (e.g., 192.168.0.0/24)."
        continue
    fi

    # Step 1.3: Store inputs in /root/eks_inputs.env (overwrite instead of appending)
    cat <<EOF > /root/eks_inputs.env
NODE_COUNT=$NODE_COUNT
AVAILABILITY_ZONE=$AVAILABILITY_ZONE
INSTANCE_TYPE=$INSTANCE_TYPE
AMI_TYPE=$AMI_TYPE
AMI_RELEASE_VERSION=$AMI_RELEASE_VERSION
SSH_KEY_PAIR=$SSH_KEY_PAIR
SUBNET_CIDR=$SUBNET_CIDR
NCS_CLUSTER_NAME=$NCS_CLUSTER_NAME
AOS_SUBNET_CIDR=$AOS_SUBNET_CIDR
VERSION=$VERSION
EOF

    # Step 1.4: Confirm success and break out of loop
    log_message "All inputs have been successfully collected and saved in /root/eks_inputs.env"
    break
done

