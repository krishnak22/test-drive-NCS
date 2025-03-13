helm delete nutanix-csi -n ntnx-system

kubectl delete ncscluster testdrive-ncs -n ncs-system

kubectl delete ncsinfra $NCS_INFRA_NAME -n $SERVICE_ACCOUNT_NAMESPACE

kubectl delete workernode $WORKERNODE_NAME -n $SERVICE_ACCOUNT_NAMESPACE

kubectl delete CustomResourceDefinition ncsinfras.ncs.nutanix.com

source eks_inputs.env
eksctl delete iamserviceaccount  --cluster $CLUSTER_NAME  --region $REGION --name $SERVICE_ACCOUNT_NAME --namespace $SERVICE_ACCOUNT_NAMESPACE

source eks_inputs.env
eksctl delete nodegroup --cluster $CLUSTER_NAME --name td-ncs-ng-1 --region $REGION --drain=false

source eks_inputs.env
controlplane $ eksctl delete cluster --name $CLUSTER_NAME --region $REGION
