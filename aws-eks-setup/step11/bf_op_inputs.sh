cat << 'EOF' > opInput.sh
#!/bin/bash

ENV_FILE="/root/eks_inputs.env"

get_input() {
    local prompt_message="$1"
    local var_name="$2"

    while true; do
        read -p "$prompt_message: " input_value
        if [[ -n "$input_value" ]]; then
            echo "$var_name=$input_value" >> "$ENV_FILE"
            break
        else
            echo "Error: $prompt_message cannot be empty. Please enter a valid value."
        fi
    done
}

# Ask for inputs and append them to eks_inputs.env
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
get_input "Enter Public Subnet ID" LB_SUBNET_ID

chmod 600 "$ENV_FILE"  # Secure the file
echo "All values saved to $ENV_FILE"
EOF

chmod +x opInput.sh
