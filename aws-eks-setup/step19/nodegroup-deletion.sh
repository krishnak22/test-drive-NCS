source eks_inputs.env
eksctl delete nodegroup --cluster $CLUSTER_NAME --name td-ncs-ng-1 --region $REGION --drain=false
