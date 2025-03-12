
cat << 'EOF' > inputs1.sh
#!/bin/bash

# Function to take and validate non-empty input
get_input() {
    local prompt_message="$1"
    local var_name="$2"

    while true; do
        read -p "$prompt_message: " input_value
        if [[ -n "$input_value" ]]; then
            eval "$var_name='$input_value'"
            break
        else
            echo "Error: $prompt_message cannot be empty. Please enter a valid value."
        fi
    done
}

# Step 1: Prompt user for inputs (one at a time)
get_input "Enter Worker Node Name" WORKER_NODE_NAME
get_input "Enter Node Pool Name" NODE_POOL_NAME
get_input "Enter Node Count" NODE_COUNT
get_input "Enter Availability Zone" AVAILABILITY_ZONE
get_input "Enter Instance Type" INSTANCE_TYPE
get_input "Enter Subnet CIDR" SUBNET_CIDR
get_input "Enter NCS Infra Name" NCS_INFRA_NAME
get_input "Enter NCS Cluster Name" NCS_CLUSTER_NAME
get_input "Enter Replication Factor" REPLICATION_FACTOR
get_input "Enter AOS Subnet CIDR" AOS_SUBNET_CIDR

# Step 2: Store inputs in environment file
ENV_FILE="/root/eks_inputs.env"
cat <<EOF >> "$ENV_FILE"
WORKER_NODE_NAME=$WORKER_NODE_NAME
NODE_POOL_NAME=$NODE_POOL_NAME
NODE_COUNT=$NODE_COUNT
AVAILABILITY_ZONE=$AVAILABILITY_ZONE
INSTANCE_TYPE=$INSTANCE_TYPE
SUBNET_CIDR=$SUBNET_CIDR
NCS_INFRA_NAME=$NCS_INFRA_NAME
NCS_CLUSTER_NAME=$NCS_CLUSTER_NAME
REPLICATION_FACTOR=$REPLICATION_FACTOR
AOS_SUBNET_CIDR=$AOS_SUBNET_CIDR
EOF

# Step 3: Confirmation message
echo "All inputs have been successfully saved in $ENV_FILE "


EOF

chmod +x inputs1.sh
