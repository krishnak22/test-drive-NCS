source eks_inputs.env

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

eksctl delete addon --cluster "$CLUSTER_NAME" --region $REGION --name metrics-server
