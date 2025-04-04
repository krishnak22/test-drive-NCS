helm repo add prometheus-community https://prometheus-community.github.io/helm-charts -n monitoring 
helm repo update

kubectl apply -f /root/scripts/pre-files/prometheus_sc.yaml --context=$CLUSTER_ARN

helm install -f  /root/scripts/yaml-files/kube-prometheus-stack-values.yaml  prometheus prometheus-community/kube-prometheus-stack --kube-context=$CLUSTER_ARN -n monitoring --version 60.0.1

kubectl apply -f /root/scripts/pre-files/prometheus_nodeport_service.yaml --context=$CLUSTER_ARN

python3 /root/scripts/create_dashboard_cm.py && kubectl apply -f /root/scripts/yaml-files/ncs-dashboard-cm-minified.yaml --context=$CLUSTER_ARN

kubectl apply -f /root/scripts/pre-files/custom_exporter_service_monitor.yaml --context=$CLUSTER_ARN

kubectl apply -f /root/scripts/pre-files/aos_publisher_service.yaml --context=$CLUSTER_ARN

kubectl apply -f /root/scripts/pre-files/aos_publisher_service_monitor.yaml --context=$CLUSTER_ARN

kubectl apply -f /root/scripts/pre-files/load_balancer.yaml --context=$CLUSTER_ARN

helm install -f /root/scripts/pre-files/cloudwatch_exporter.yaml cloudwatch-exporter prometheus-community/prometheus-cloudwatch-exporter --kube-context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr  -n monitoring --version 0.25.3
