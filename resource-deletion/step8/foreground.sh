source eks_inputs.env
eksctl delete cluster --name $CLUSTER_NAME --region $REGION
