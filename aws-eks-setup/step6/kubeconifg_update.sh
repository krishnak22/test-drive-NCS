source eks_inputs.env

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
echo "CLUSTER_ARN=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.arn" --output text)" >> eks_inputs.env
eksctl delete addon --cluster "$CLUSTER_NAME" --region $REGION --name metrics-server
