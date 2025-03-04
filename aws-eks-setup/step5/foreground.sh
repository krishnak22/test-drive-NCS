#!/bin/bash

# Define valid AWS regions in an array
declare -a aws_regions=("us-east-1" "us-west-1" "us-west-2" "us-east-2" "ca-central-1" "eu-west-1" "eu-west-2" "eu-central-1" "ap-southeast-1" "ap-southeast-2" "ap-northeast-1" "ap-northeast-2" "sa-east-1" "af-south-1" "eu-north-1" "me-south-1" "ap-south-1" "ap-east-1" "us-gov-west-1" "us-gov-east-1")

# Validate if a given value exists in an array
validate_in_array() {
    local value=$1
    shift
    local array=("$@")
    for item in "${array[@]}"; do
        if [[ "$item" == "$value" ]]; then
            return 0
        fi
    done
    return 1
}

# Validate subnet format (CIDR)
validate_subnet_format() {
    local subnet=$1
    [[ "$subnet" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]
}

# Main function to get and validate inputs
get_input() {
    local prompt=$1
    local var_name=$2
    local validation_func=$3
    local validation_args=("${@:4}")

    while : ; do
        read -p "$prompt" "$var_name"
        if [[ -z "${!var_name}" ]]; then
            echo "$var_name cannot be empty. Please try again."
        elif $validation_func "${!var_name}" "${validation_args[@]}"; then
            return 0
        else
            echo "Invalid input for $var_name. Please try again."
        fi
    done
}

# Gather user inputs
get_input "Enter the cluster name: " cluster_name validate_in_array "^[a-zA-Z0-9-]+$"
get_input "Enter the region: " region validate_in_array "$aws_regions"
get_input "Enter the subnets (comma-separated CIDR format): " subnets validate_subnet_format
get_input "Enter the primary owner: " primary_owner validate_in_array "."

# Save inputs to eks_inputs.env
cat <<EOF > eks_inputs.env
CLUSTER_NAME=$cluster_name
REGION=$region
SUBNETS=$subnets
PRIMARY_OWNER=$primary_owner
EOF

echo "Configuration has been saved to eks_inputs.env."

