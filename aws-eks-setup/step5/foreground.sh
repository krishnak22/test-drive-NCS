#!/bin/bash

set -euo pipefail  # Enable strict error handling

LOG_FILE="eks_setup.log"
ENV_FILE="eks_inputs.env"

clear
echo "=========================================" | tee -a "$LOG_FILE"
echo "   AWS EKS Cluster Creation Wizard" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"

# List of valid AWS regions
VALID_REGIONS=("us-east-1" "us-east-2" "us-west-1" "us-west-2" "eu-central-1" "eu-west-1" "eu-west-2" "ap-south-1" "ap-northeast-1")

# Function to log messages
log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to validate cluster name
validate_cluster_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
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
    read -p "Enter Cluster Name: " CLUSTER_NAME
    read -p "Enter AWS Region: " REGION
    read -p "Enter VPC Private Subnets (comma-separated): " VPC_SUBNETS

    # Step 1.2: Validate inputs
    if [[ -z "$CLUSTER_NAME" || -z "$REGION" || -z "$VPC_SUBNETS" ]]; then
        log_message "Error: All fields are required. Please enter valid values."
        continue
    fi

    # Validate Cluster Name
    if ! validate_cluster_name "$CLUSTER_NAME"; then
        log_message "Error: Invalid cluster name. Please follow AWS naming rules."
        continue
    fi

    # Validate AWS Region
    if [[ ! " ${VALID_REGIONS[@]} " =~ " ${REGION} " ]]; then
        log_message "Error: '$REGION' is not a valid AWS region."
        continue
    fi

    # Check if the cluster already exists
    if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
        log_message "Error: Cluster '$CLUSTER_NAME' already exists in region '$REGION'. Choose a different name."
        continue
    fi

    # Validate Subnets
    VALID_SUBNETS=true
    for SUBNET in ${VPC_SUBNETS//,/ }; do
        if ! aws ec2 describe-subnets --subnet-ids "$SUBNET" --region "$REGION" >/dev/null 2>&1; then
            log_message "Error: Subnet ID '$SUBNET' is invalid or does not exist in region '$REGION'."
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
    read -p "Do you want to proceed? (yes/no): " CONFIRM

    if [[ "$CONFIRM" == "yes" ]]; then
        # Store validated inputs in env file
        echo "CLUSTER_NAME=$CLUSTER_NAME" > "$ENV_FILE"
        echo "REGION=$REGION" >> "$ENV_FILE"
        echo "VPC_SUBNETS=$VPC_SUBNETS" >> "$ENV_FILE"
        
        log_message "Inputs validated successfully. Run './eks_create.sh' to create the cluster."
        break
    else
        log_message "User chose to re-enter inputs. Restarting input process..."
    fi
done

