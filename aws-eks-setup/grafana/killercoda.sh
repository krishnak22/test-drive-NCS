controlplane:~$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts -n monitoring
"prometheus-community" has been added to your repositories
controlplane:~$ cat << EOF > Prometheus_sc.yaml
> apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: prometheus-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
EOF
controlplane:~$ 
controlplane:~$ 
controlplane:~$ ls
Prometheus_sc.yaml  aws  awscliv2.zip  filesystem
controlplane:~$ vi Prometheus_sc.yaml 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ kubectl apply -f Prometheus_sc.yaml 
storageclass.storage.k8s.io/prometheus-sc created
controlplane:~$ 
controlplane:~$ 
controlplane:~$ vi grafana_deploy.yaml
controlplane:~$ 
controlplane:~$ ls
Prometheus_sc.yaml  aws  awscliv2.zip  filesystem  grafana_deploy.yaml
controlplane:~$ vi kube-prometheus-stack-values.yaml
controlplane:~$ 
controlplane:~$ 
controlplane:~$ helm install -f kube-prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack --kube-context=arn:aws:iam::353502843997:role/NCS-krishna-cluster-22jan-yIvgPhuFcy-EKSCluster -n monitoring --version 60.0.1
Error: INSTALLATION FAILED: Kubernetes cluster unreachable: context "arn:aws:iam::353502843997:role/NCS-krishna-cluster-22jan-yIvgPhuFcy-EKSCluster" does not exist
controlplane:~$ 
controlplane:~$ 
controlplane:~$ ls
Prometheus_sc.yaml  aws  awscliv2.zip  filesystem  grafana_deploy.yaml  kube-prometheus-stack-values.yaml
controlplane:~$ helm install -f kube-prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack --kube-context="arn:aws:iam::353502843997:role/NCS-krishna-cluster-22jan-yIvgPhuFcy-EKSCluster" -n monitoring --version "60.0.1"
Error: INSTALLATION FAILED: Kubernetes cluster unreachable: context "arn:aws:iam::353502843997:role/NCS-krishna-cluster-22jan-yIvgPhuFcy-EKSCluster" does not exist
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ aws sts get-caller-identity
{
    "UserId": "AROAVETTJKRO27CZXZHKY:NCS-Test-Drive",
    "Account": "353502843997",
    "Arn": "arn:aws:sts::353502843997:assumed-role/ncs-storage-22-jan-prac-NCSOrchestratorRole-jDzPo7jpn5DO/NCS-Test-Drive"
}
controlplane:~$ helm install -f kube-prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack --kube-context="arn:aws:eks:us-west-2:353502843997:cluster/krishna-eks-22-jan" -n monitoring --version "60.0.1"
NAME: prometheus
LAST DEPLOYED: Tue Apr  1 11:30:52 2025
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=prometheus"

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.
controlplane:~$ kubectl --namespace monitoring get pods -l "release=prometheus"
NAME                                                   READY   STATUS    RESTARTS   AGE
prometheus-kube-prometheus-operator-56b5d9f677-jvv9m   1/1     Running   0          55s
prometheus-kube-state-metrics-5fd6db75d7-9cbrb         1/1     Running   0          55s
prometheus-prometheus-node-exporter-x6n24              1/1     Running   0          56s
controlplane:~$ 
controlplane:~$ 
controlplane:~$ vi prometheus_nodeport_svc.yaml
controlplane:~$ 
controlplane:~$ 
controlplane:~$ kubectl apply -f prometheus_nodeport_svc.yaml --context "arn:aws:eks:us-west-2:353502843997:cluster/krishna-eks-22-jan"
service/prometheus-service created
controlplane:~$ 
controlplane:~$ 
controlplane:~$ vi create_dashboard_cm.py
controlplane:~$ python3 create_dashboard_cm.py
Traceback (most recent call last):
  File "/root/create_dashboard_cm.py", line 5, in <module>
    from config import logger
ModuleNotFoundError: No module named 'config'
controlplane:~$ vi create_dashboard_cm.py
controlplane:~$ vi config.py
controlplane:~$ python3 create_dashboard_cm.py
Traceback (most recent call last):
  File "/root/create_dashboard_cm.py", line 18, in minify_json
    with open(input_file, "r") as file:
         ^^^^^^^^^^^^^^^^^^^^^
FileNotFoundError: [Errno 2] No such file or directory: '/root/json-files/ncs_dashboard.json'

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "/root/create_dashboard_cm.py", line 128, in <module>
    main()
  File "/root/create_dashboard_cm.py", line 118, in main
    create_ncs_dashboard_cm(
  File "/root/create_dashboard_cm.py", line 69, in create_ncs_dashboard_cm
    json_string = minify_json(input_file)
                  ^^^^^^^^^^^^^^^^^^^^^^^
  File "/root/create_dashboard_cm.py", line 23, in minify_json
    raise Exception(
Exception: Cannot find the JSON file for the NCS Dashboard. Reason: [Errno 2] No such file or directory: '/root/json-files/ncs_dashboard.json'
controlplane:~$ vi ncs_dashboard.json
controlplane:~$ 
controlplane:~$ 
controlplane:~$ python3 create_dashboard_cm.py
Traceback (most recent call last):
  File "/root/create_dashboard_cm.py", line 18, in minify_json
    with open(input_file, "r") as file:
         ^^^^^^^^^^^^^^^^^^^^^
FileNotFoundError: [Errno 2] No such file or directory: '/root/json-files/ncs_dashboard.json'

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "/root/create_dashboard_cm.py", line 128, in <module>
    main()
  File "/root/create_dashboard_cm.py", line 118, in main
    create_ncs_dashboard_cm(
  File "/root/create_dashboard_cm.py", line 69, in create_ncs_dashboard_cm
    json_string = minify_json(input_file)
                  ^^^^^^^^^^^^^^^^^^^^^^^
  File "/root/create_dashboard_cm.py", line 23, in minify_json
    raise Exception(
Exception: Cannot find the JSON file for the NCS Dashboard. Reason: [Errno 2] No such file or directory: '/root/json-files/ncs_dashboard.json'
controlplane:~$ vi ncs_dashboard.json 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ vi create_dashboard_cm.py 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ mkdir json-files
controlplane:~$ ls
Prometheus_sc.yaml  __pycache__  aws  awscliv2.zip  config.py  create_dashboard_cm.py  deployment.log  filesystem  grafana_deploy.yaml  json-files  kube-prometheus-stack-values.yaml  ncs_dashboard.json  prometheus_nodeport_svc.yaml
controlplane:~$ mv ncs_dashboard.json /root/json-files/
controlplane:~$ ls
Prometheus_sc.yaml  __pycache__  aws  awscliv2.zip  config.py  create_dashboard_cm.py  deployment.log  filesystem  grafana_deploy.yaml  json-files  kube-prometheus-stack-values.yaml  prometheus_nodeport_svc.yaml
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ python3 create_dashboard_cm.py
Traceback (most recent call last):
  File "/root/create_dashboard_cm.py", line 87, in create_ncs_dashboard_cm
    with open(output_file, "w") as file:
         ^^^^^^^^^^^^^^^^^^^^^^
FileNotFoundError: [Errno 2] No such file or directory: '/root/yaml-files/ncs-dashboard-cm-minified.yaml'

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "/root/create_dashboard_cm.py", line 128, in <module>
    main()
  File "/root/create_dashboard_cm.py", line 118, in main
    create_ncs_dashboard_cm(
  File "/root/create_dashboard_cm.py", line 93, in create_ncs_dashboard_cm
    raise Exception(
Exception: Error in writing the ConfigMap YAML File: /root/yaml-files/ncs-dashboard-cm-minified.yaml. Reason: [Errno 2] No such file or directory: '/root/yaml-files/ncs-dashboard-cm-minified.yaml'
controlplane:~$ mkdir yaml-files
controlplane:~$ cd yaml-files/
controlplane:~/yaml-files$ vi ncs-dashboard-cm-minified.yaml
controlplane:~/yaml-files$ 
controlplane:~/yaml-files$ 
controlplane:~/yaml-files$ 
controlplane:~/yaml-files$ cd ..
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ ls
Prometheus_sc.yaml  __pycache__  aws  awscliv2.zip  config.py  create_dashboard_cm.py  deployment.log  filesystem  grafana_deploy.yaml  json-files  kube-prometheus-stack-values.yaml  prometheus_nodeport_svc.yaml  yaml-files
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ python3 create_dashboard_cm.py
controlplane:~$ 
controlplane:~$ 
controlplane:~$ cd yaml-files/
controlplane:~/yaml-files$ ls
ncs-dashboard-cm-minified.yaml
controlplane:~/yaml-files$ vi ncs-dashboard-cm-minified.yaml 
controlplane:~/yaml-files$ 
controlplane:~/yaml-files$ 
controlplane:~/yaml-files$ 
controlplane:~/yaml-files$ cd ..
controlplane:~$ cd yaml-files/
controlplane:~/yaml-files$ kubectl apply -f ncs-dashboard-cm-minified.yaml
configmap/ncs-dashboard-configmap created
controlplane:~/yaml-files$ kubectl delete -f ncs-dashboard-cm-minified.yaml 
configmap "ncs-dashboard-configmap" deleted
controlplane:~/yaml-files$ kubectl apply -f ncs-dashboard-cm-minified.yaml --context ncs-dashboard-cm-minified.yaml
error: context "ncs-dashboard-cm-minified.yaml" does not exist
controlplane:~/yaml-files$ kubectl apply -f ncs-dashboard-cm-minified.yaml --context arn:aws:eks:us-west-2:353502843997:cluster/krishna-eks-22-jan
configmap/ncs-dashboard-configmap created
controlplane:~/yaml-files$ 
controlplane:~/yaml-files$ 
controlplane:~/yaml-files$ cd ..
controlplane:~$ vi load_balancer_yaml
controlplane:~$ 
