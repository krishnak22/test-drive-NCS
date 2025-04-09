source eks_inputs.env
kubectl delete storageclass prometheus-sc --context=$CLUSTER_ARN --ignore-not-found=true

helm uninstall prometheus -n monitoring --kube-context=$CLUSTER_ARN --ignore-not-found=true && kubectl delete pvc -n monitoring prometheus-prometheus-kube-prometheus-prometheus-db-prometheus-prometheus-kube-prometheus-prometheus-0 --context=$CLUSTER_ARN --ignore-not-found=true && kubectl delete pvc -n monitoring prometheus-grafana --context=$CLUSTER_ARN --ignore-not-found=true

kubectl delete svc -n monitoring prometheus-service -n monitoring --ignore-not-found=true --context=$CLUSTER_ARN

kubectl delete configmap ncs-dashboard-configmap -n monitoring --context=$CLUSTER_ARN --ignore-not-found=true

kubectl delete servicemonitor metadata-exporter-monitor -n monitoring --ignore-not-found=true --context=$CLUSTER_ARN

kubectl delete svc aos-publisher-service -n ncs-system  --ignore-not-found=true --context=$CLUSTER_ARN

kubectl delete servicemonitor aos-publisher-service-monitor -n monitoring --ignore-not-found=true --context=$CLUSTER_ARN

kubectl delete service grafana-lb-service -n monitoring --ignore-not-found=true --context=$CLUSTER_ARN

helm uninstall cloudwatch-exporter -n monitoring --kube-context=$CLUSTER_ARN --ignore-not-found

kubectl delete pod postgres

kubectl delete configmap postgres-config

kubectl delete pvc postgresql-claim

kubectl delete storageclass base-sc

helm delete nutanix-csi -n ntnx-system

source eks_inputs.env
kubectl delete ncscluster $NCS_CLUSTER_NAME -n ncs-system

source eks_inputs.env
kubectl delete ncsinfra $NCS_INFRA_NAME -n $SERVICE_ACCOUNT_NAMESPACE

source eks_inputs.env
kubectl delete workernode $WORKER_NODE_NAME -n $SERVICE_ACCOUNT_NAMESPACE

kubectl delete CustomResourceDefinition ncsinfras.ncs.nutanix.com

source eks_inputs.env
eksctl delete iamserviceaccount  --cluster $CLUSTER_NAME  --region $REGION --name $SERVICE_ACCOUNT_NAME --namespace $SERVICE_ACCOUNT_NAMESPACE
