source eks_inputs.env

eksctl create nodegroup --cluster "$CLUSTER_NAME" --region "$REGION" --version 1.30 --nodes-min 1 --nodes-max 1 --node-type t3.medium --name td-ncs-ng-1 --node-private-networking
