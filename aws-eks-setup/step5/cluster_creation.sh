if [[ ! -f eks_inputs.env ]]; then
    echo "Error: eks_inputs.env file not found. Run './eks_input.sh' first."
fi

source eks_inputs.env

echo -e "\nStarting EKS cluster creation..."
eksctl create cluster --name "$CLUSTER_NAME" --region "$REGION" --vpc-private-subnets "$VPC_SUBNETS" --without-nodegroup --tags primary-owner="$PRIMARY_OWNER"


