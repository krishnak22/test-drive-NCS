cat << 'EOF' > inputs.sh
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
    echo -n "Enter VPC Private Subnets (comma-separated): "
    read -r VPC_SUBNETS
    echo -n "Enter the primary-owner tag value: "
    read -r PRIMARY_OWNER

    # Step 1.2: Validate inputs
    if [[ -z "$CLUSTER_NAME" || -z "$REGION" || -z "$VPC_SUBNETS" || -z "$PRIMARY_OWNER" ]]; then
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

    # Check if the cluster already exists
    if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
        echo "Error: Cluster '$CLUSTER_NAME' already exists in region '$REGION'. Choose a different name."
        continue
    fi

    # Validate Subnets
    VALID_SUBNETS=true
    for SUBNET in ${VPC_SUBNETS//,/ }; do
        if ! aws ec2 describe-subnets --subnet-ids "$SUBNET" --region "$REGION" >/dev/null 2>&1; then
            echo "Error: Subnet ID '$SUBNET' is invalid or does not exist in region '$REGION'."
            VALID_SUBNETS=false
        fi
    done
    if [ "$VALID_SUBNETS" = false ]; then
        continue
    fi

    # Confirm user inputs before proceeding
    echo -e "\nYou have entered:"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Region: $REGION"
    echo "VPC Private Subnets: $VPC_SUBNETS"
    echo "Primary Owner: $PRIMARY_OWNER"
    read -p "Do you want to proceed? (yes/no): " CONFIRM

    if [[ "$CONFIRM" == "yes" ]]; then
        # Store validated inputs in env file
        echo "CLUSTER_NAME=$CLUSTER_NAME" > "$ENV_FILE"
        echo "REGION=$REGION" >> "$ENV_FILE"
        echo "VPC_SUBNETS=$VPC_SUBNETS" >> "$ENV_FILE"
        echo "PRIMARY_OWNER=$PRIMARY_OWNER" >> "$ENV_FILE"
        break
    fi

done
EOF
# Change the mode of inputs.sh to make it executable
chmod +x inputs.sh

# Run the inputs.sh script
./inputs.sh

