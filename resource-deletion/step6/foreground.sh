source eks_inputs.env
kubectl delete storageclass prometheus-sc --ignore-not-found=true

helm uninstall prometheus -n monitoring --ignore-not-found=true && kubectl delete pvc -n monitoring prometheus-prometheus-kube-prometheus-prometheus-db-prometheus-prometheus-kube-prometheus-prometheus-0 --ignore-not-found=true && kubectl delete pvc -n monitoring prometheus-grafana --ignore-not-found=true

kubectl delete svc -n monitoring prometheus-service -n monitoring --ignore-not-found=true 

kubectl delete configmap ncs-dashboard-configmap -n monitoring --ignore-not-found=true

kubectl delete servicemonitor metadata-exporter-monitor -n monitoring --ignore-not-found=true

kubectl delete svc aos-publisher-service -n ncs-system  --ignore-not-found=true

kubectl delete servicemonitor aos-publisher-service-monitor -n monitoring --ignore-not-found=true

kubectl delete service grafana-lb-service -n monitoring --ignore-not-found=true 

helm uninstall cloudwatch-exporter -n monitoring --ignore-not-found

kubectl delete pod postgres --ignore-not-found=true

kubectl delete configmap postgres-config --ignore-not-found=true

kubectl delete pvc postgresql-claim --ignore-not-found=true

kubectl delete storageclass base-sc --ignore-not-found=true

helm delete nutanix-csi -n ntnx-system --ignore-not-found=true

source eks_inputs.env
kubectl delete ncscluster $CLUSTER_NAME-cn-aos-cl -n ncs-system --ignore-not-found=true

source eks_inputs.env
kubectl delete ncsinfra $CLUSTER_NAME-cn-aos-infra -n ncs-infra-deployment-operator-system --ignore-not-found=true

source eks_inputs.env
kubectl delete workernode $CLUSTER_NAME-wn -n ncs-infra-deployment-operator-system --ignore-not-found=true

kubectl delete CustomResourceDefinition ncsinfras.ncs.nutanix.com --ignore-not-found=true

source eks_inputs.env
eksctl delete iamserviceaccount  --cluster $CLUSTER_NAME  --region $REGION --name ncs-infra-sa-new-2 --namespace ncs-infra-deployment-operator-system 
