if [[ ! -f eks_inputs.env ]]; then
    echo "Error: eks_inputs.env file not found. Run './eks_input.sh' first."
else
CREATION_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
source eks_inputs.env

echo -e "\nStarting EKS cluster creation..."
eksctl create cluster --name "$CLUSTER_NAME" --region "$REGION" --version 1.30 --vpc-private-subnets "$VPC_SUBNETS" --without-nodegroup --tags primary-owner="$PRIMARY_OWNER",platform="KILLERCODA",creation-time="$CREATION_TIME"
fi

