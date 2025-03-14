kubectl delete pod postgres

kubectl delete configmap postgres-config

kubectl delete pvc postgresql-claim

kubectl delete storageclass base-sc

helm delete nutanix-csi -n ntnx-system

kubectl delete ncscluster testdrive-ncs -n ncs-system

source eks_inputs.env
kubectl delete ncsinfra $NCS_INFRA_NAME -n $SERVICE_ACCOUNT_NAMESPACE

source eks_inputs.env
kubectl delete workernode $WORKERNODE_NAME -n $SERVICE_ACCOUNT_NAMESPACE

kubectl delete CustomResourceDefinition ncsinfras.ncs.nutanix.com

source eks_inputs.env
eksctl delete iamserviceaccount  --cluster $CLUSTER_NAME  --region $REGION --name $SERVICE_ACCOUNT_NAME --namespace $SERVICE_ACCOUNT_NAMESPACE
