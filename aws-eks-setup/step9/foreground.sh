source eks_inputs.env

eksctl create nodegroup --cluster "$CLUSTER_NAME" —-region "$REGION" --nodes-min 1 --nodes-max 1 —-node
-type t3.medium —name test-drive-ncs-ng-1 --node-private-networking


echo "NodeGroup_Name=test-drive-ncs-ng-1" >> eks_inputs.env
