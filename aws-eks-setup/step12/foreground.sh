while true; do
    # Prompt user for inputs
    read -p "Enter WorkerNode name: " WORKER_NODE_NAME
    if [[ -z "$WORKER_NODE_NAME" ]]; then
        echo "Error: WorkerNode name is required. Please enter a valid value."
        continue
    fi

    read -p "Enter Node Pool name: " NODE_POOL_NAME
    if [[ -z "$NODE_POOL_NAME" ]]; then
        echo "Error: Node Pool name is required. Please enter a valid value."
        continue
    fi

    read -p "Enter Node count: " NODE_COUNT
    if [[ -z "$NODE_COUNT" ]]; then
        echo "Error: Node count is required. Please enter a valid value."
        continue
    fi

    read -p "Enter Availability Zone: " AVAILABILITY_ZONE
    if [[ -z "$AVAILABILITY_ZONE" ]]; then
        echo "Error: Availability Zone is required. Please enter a valid value."
        continue
    fi

    read -p "Enter Instance Type: " INSTANCE_TYPE
    if [[ -z "$INSTANCE_TYPE" ]]; then
        echo "Error: Instance Type is required. Please enter a valid value."
        continue
    fi

    read -p "Enter AMI Type: " AMI_TYPE
    if [[ -z "$AMI_TYPE" ]]; then
        echo "Error: AMI Type is required. Please enter a valid value."
        continue
    fi

    read -p "Enter AMI Release Version: " AMI_RELEASE_VERSION
    if [[ -z "$AMI_RELEASE_VERSION" ]]; then
        echo "Error: AMI Release Version is required. Please enter a valid value."
        continue
    fi

    read -p "Enter SSH Key Pair: " SSH_KEY_PAIR
    if [[ -z "$SSH_KEY_PAIR" ]]; then
        echo "Error: SSH Key Pair is required. Please enter a valid value."
        continue
    fi

    read -p "Enter Subnet CIDR: " SUBNET_CIDR
    if [[ -z "$SUBNET_CIDR" ]]; then
        echo "Error: Subnet CIDR is required. Please enter a valid value."
        continue
    fi

    read -p "Enter NCS Infra Name: " NCS_INFRA_NAME
    if [[ -z "$NCS_INFRA_NAME" ]]; then
        echo "Error: NCS Infra Name is required. Please enter a valid value."
        continue
    fi

    read -p "Enter NCS Cluster Name: " NCS_CLUSTER_NAME
    if [[ -z "$NCS_CLUSTER_NAME" ]]; then
        echo "Error: NCS Cluster Name is required. Please enter a valid value."
        continue
    fi

    read -p "Enter Replication Factor: " REPLICATION_FACTOR
    if [[ -z "$REPLICATION_FACTOR" ]]; then
        echo "Error: Replication Factor is required. Please enter a valid value."
        continue
    fi

    read -p "Enter AOS Subnet CIDR: " AOS_SUBNET_CIDR
    if [[ -z "$AOS_SUBNET_CIDR" ]]; then
        echo "Error: AOS Subnet CIDR is required. Please enter a valid value."
        continue
    fi

    read -p "Enter Version: " VERSION
    if [[ -z "$VERSION" ]]; then
        echo "Error: Version is required. Please enter a valid value."
        continue
    fi

    # If all fields are filled, break out of the loop
    break
done

# Store the values in the eks_inputs.env file
{
    echo "WORKER_NODE_NAME=\"$WORKER_NODE_NAME\""
    echo "NODE_POOL_NAME=\"$NODE_POOL_NAME\""
    echo "NODE_COUNT=\"$NODE_COUNT\""
    echo "AVAILABILITY_ZONE=\"$AVAILABILITY_ZONE\""
    echo "INSTANCE_TYPE=\"$INSTANCE_TYPE\""
    echo "AMI_TYPE=\"$AMI_TYPE\""
    echo "AMI_RELEASE_VERSION=\"$AMI_RELEASE_VERSION\""
    echo "SSH_KEY_PAIR=\"$SSH_KEY_PAIR\""
    echo "SUBNET_CIDR=\"$SUBNET_CIDR\""
    echo "NCS_INFRA_NAME=\"$NCS_INFRA_NAME\""
    echo "NCS_CLUSTER_NAME=\"$NCS_CLUSTER_NAME\""
    echo "REPLICATION_FACTOR=\"$REPLICATION_FACTOR\""
    echo "AOS_SUBNET_CIDR=\"$AOS_SUBNET_CIDR\""
    echo "VERSION=\"$VERSION\""
} >> eks_inputs.env

echo "The values have been stored in eks_inputs.env."

