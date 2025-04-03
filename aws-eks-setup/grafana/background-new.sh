helm repo add prometheus-community https://prometheus-community.github.io/helm-charts -n monitoring
helm repo update

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: prometheus-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  tagSpecification_1: primary_owner=${var.primary_owner}
  tagSpecification_2: ncs-cluster-name=${var.ncs_cluster_name}
volumeBindingMode: WaitForFirstConsumer

kube prometheus stack file creation

helm install -f /root/scripts/yaml-files/kube-prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack --kube-context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr -n monitoring --version 60.0.1

nodeport_svc yaml creation
 kubectl apply -f nodeport_svc.yaml --context arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr


create scripts/create_dashboard_cm.py  scripts/config.py  scripts/json-files/ncs_dashboard.json


python3  /root/scripts/create_dashboard_cm.py &&  kubectl apply -f /root/scripts/yaml-files/ncs-dashboard-cm-minified.yaml --context arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr

apiVersion: v1
kind: Service
metadata:
  name: grafana-lb-service
  namespace: monitoring
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-subnets: subnet-0f78c0576037daafe
    service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: ${local.grafana_load_balancer_tags_str}
spec:
  type: LoadBalancer
  ports:
    - name: grafana-lb
      port: 3000
      targetPort: 3000
      protocol: TCP
  selector:
    app.kubernetes.io/name: grafana
  loadBalancerSourceRanges:
    - ${var.user_ip_cidr}
