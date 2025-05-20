CREATION_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
source eks_inputs.env

eksctl create nodegroup --cluster "$CLUSTER_NAME" --region "$REGION" --nodes-min 1 --nodes-max 1 --node-type t3.medium --name td-ncs-ng-1 --node-private-networking --tags kc-cluster-name="$CLUSTER_NAME",creation-time="$CREATION_TIME"
