source eks_inputs.env

echo "WORKER_NODE_NAME=$CLUSTER_NAME-wn" >> eks_inputs.env
echo "NODE_POOL_NAME=$CLUSTER_NAME-np" >> eks_inputs.env
echo "NCS_CLUSTER_NAME=$CLUSTER_NAME-cn-aos-cl" >> eks_inputs.env
echo "NCS_INFRA_NAME=$CLUSTER_NAME-cn-aos-infra" >> eks_inputs.env
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
get_input "Enter Node Count" NODE_COUNT
get_input "Enter Availability Zone" AVAILABILITY_ZONE
get_input "Enter Instance Type" INSTANCE_TYPE
get_input "Enter Worker Node Subnet CIDR" SUBNET_CIDR
get_input "Enter AOS Subnet CIDR" AOS_SUBNET_CIDR
get_input "Enter Public Subnet ID" LB_SUBNET_ID

chmod 600 "$ENV_FILE"  # Secure the file
echo "All values saved to $ENV_FILE"
EOF

chmod +x opInput.sh
