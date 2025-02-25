source eks_inputs.env

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
