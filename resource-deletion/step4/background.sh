cat << 'EOF' > clusterInputs.sh
ENV_FILE="eks_inputs.env"

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

while true; do
    # Step 1.1: Prompt user for inputs
    echo -n "Enter Cluster Name: "
    read -r CLUSTER_NAME
    echo -n  "Enter AWS Region: "
    read -r REGION
    
    # Step 1.2: Validate inputs
    if [[ -z "$CLUSTER_NAME" || -z "$REGION" ]]; then
        echo "Error: All fields are required. Please enter valid values."
        continue
    fi

    # Validate Cluster Name
    if ! validate_cluster_name "$CLUSTER_NAME"; then
        continue
    fi

    # Validate AWS Region
    if [[ ! " ${VALID_REGIONS[@]} " =~ " ${REGION} " ]]; then
        echo "Error: '$REGION' is not a valid AWS region."
        continue
    fi
    echo "CLUSTER_NAME=$CLUSTER_NAME" > "$ENV_FILE"
    echo "REGION=$REGION" >> "$ENV_FILE"
done

chmod + chmod +x clusterInputs.sh
