ontrolplane:~$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts -n monitoring
"prometheus-community" has been added to your repositories
controlplane:~$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "prometheus-community" chart repository
Update Complete. ⎈Happy Helming!⎈
controlplane:~$ vi prometheus_sc.yaml
controlplane:~$ 
controlplane:~$ 
controlplane:~$ kubectl apply -f prometheus_sc.yaml --context arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr
storageclass.storage.k8s.io/prometheus-sc created
controlplane:~$ kubectl describe sc prometheus-sc   
Name:            prometheus-sc
IsDefaultClass:  No
Annotations:     kubectl.kubernetes.io/last-applied-configuration={"apiVersion":"storage.k8s.io/v1","kind":"StorageClass","metadata":{"annotations":{},"name":"prometheus-sc"},"parameters":{"fsType":"ext4","tagSpecification_1":"primary_owner=${var.primary_owner}","tagSpecification_2":"ncs-cluster-name=${var.ncs_cluster_name}","type":"gp3"},"provisioner":"ebs.csi.aws.com","volumeBindingMode":"WaitForFirstConsumer"}

Provisioner:           ebs.csi.aws.com
Parameters:            fsType=ext4,tagSpecification_1=primary_owner=${var.primary_owner},tagSpecification_2=ncs-cluster-name=${var.ncs_cluster_name},type=gp3
AllowVolumeExpansion:  <unset>
MountOptions:          <none>
ReclaimPolicy:         Delete
VolumeBindingMode:     WaitForFirstConsumer
Events:                <none>
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ mkdir stack
controlplane:~$ cd stack/
controlplane:~/stack$ mkdir yaml-files
controlplane:~/stack$ cd yaml-files/
controlplane:~/stack/yaml-files$ vi kube-prometheus-stack-values.yaml
controlplane:~/stack/yaml-files$ 
controlplane:~/stack/yaml-files$ 
controlplane:~/stack/yaml-files$ cd ../..
controlplane:~$ mv stack stacks
controlplane:~$ ls
aws  awscliv2.zip  eks_inputs.env  filesystem  prometheus_sc.yaml  stacks
controlplane:~$ mv stacks scripts
controlplane:~$ ls
aws  awscliv2.zip  eks_inputs.env  filesystem  prometheus_sc.yaml  scripts
controlplane:~$ helm install -f /scripts/yaml-files/kube-prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack --kube-context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr -n monitoring --version 60.0.1
Error: INSTALLATION FAILED: open /scripts/yaml-files/kube-prometheus-stack-values.yaml: no such file or directory
controlplane:~$ helm install -f /root/scripts/yaml-files/kube-prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack --kube-context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr -n monitoring --version 60.0.1        
NAME: prometheus
LAST DEPLOYED: Wed Apr  2 10:54:02 2025
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace monitoring get pods -l "release=prometheus"

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.
controlplane:~$ vi nodeport_svc.yaml
controlplane:~$ 
controlplane:~$ kubectl apply -f nodeport_svc.yaml --context arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr
service/prometheus-service created
controlplane:~$ cd scripts/
controlplane:~/scripts$ vi create_dashboard_cm.py
controlplane:~/scripts$ 
controlplane:~/scripts$ 
controlplane:~/scripts$ cd ..
controlplane:~$ python3 /root/scripts/create_dashboard_cm.py ^C
controlplane:~$ ^C
controlplane:~$ 
controlplane:~$ 
controlplane:~$ cd scripts/
controlplane:~/scripts$ cd yaml-files/
controlplane:~/scripts/yaml-files$ cd ../..
controlplane:~$ 
controlplane:~$ ls                                           
aws  awscliv2.zip  eks_inputs.env  filesystem  nodeport_svc.yaml  prometheus_sc.yaml  scripts
controlplane:~$ cd scripts/
controlplane:~/scripts$ ls
create_dashboard_cm.py  yaml-files
controlplane:~/scripts$ cd ..
controlplane:~$ python3  /root/scripts/create_dashboard_cm.py &&  kubectl apply -f /root/scripts/yaml-files/ncs-dashboard-cm-minified.yaml --context arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr
Traceback (most recent call last):
  File "/root/scripts/create_dashboard_cm.py", line 6, in <module>
    from config import logger
ModuleNotFoundError: No module named 'config'
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ cd scripts/
controlplane:~/scripts$ vi config.py
controlplane:~/scripts$ 
controlplane:~/scripts$ 
controlplane:~/scripts$ cd ..
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ python3  /root/scripts/create_dashboard_cm.py &&  kubectl apply -f /root/scripts/yaml-files/ncs-dashboard-cm-minified.yaml --context arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr
Traceback (most recent call last):
  File "/root/scripts/create_dashboard_cm.py", line 19, in minify_json
    with open(input_file, "r") as file:
         ^^^^^^^^^^^^^^^^^^^^^
FileNotFoundError: [Errno 2] No such file or directory: '/root/scripts/json-files/ncs_dashboard.json'

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "/root/scripts/create_dashboard_cm.py", line 129, in <module>
    main()
  File "/root/scripts/create_dashboard_cm.py", line 119, in main
    create_ncs_dashboard_cm(
  File "/root/scripts/create_dashboard_cm.py", line 70, in create_ncs_dashboard_cm
    json_string = minify_json(input_file)
                  ^^^^^^^^^^^^^^^^^^^^^^^
  File "/root/scripts/create_dashboard_cm.py", line 24, in minify_json
    raise Exception(
Exception: Cannot find the JSON file for the NCS Dashboard. Reason: [Errno 2] No such file or directory: '/root/scripts/json-files/ncs_dashboard.json'
controlplane:~$    
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ cd scripts/
controlplane:~/scripts$ 
controlplane:~/scripts$ 
controlplane:~/scripts$ mkdir json-files
controlplane:~/scripts$ cd json-files/
controlplane:~/scripts/json-files$ vi ncs-dashboard.json
controlplane:~/scripts/json-files$ 
controlplane:~/scripts/json-files$ 
controlplane:~/scripts/json-files$ cd ../..
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ python3  /root/scripts/create_dashboard_cm.py &&  kubectl apply -f /root/scripts/yaml-files/ncs-dashboard-cm-minified.yaml --context arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr
Traceback (most recent call last):
  File "/root/scripts/create_dashboard_cm.py", line 19, in minify_json
    with open(input_file, "r") as file:
         ^^^^^^^^^^^^^^^^^^^^^
FileNotFoundError: [Errno 2] No such file or directory: '/root/scripts/json-files/ncs_dashboard.json'

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "/root/scripts/create_dashboard_cm.py", line 129, in <module>
    main()
  File "/root/scripts/create_dashboard_cm.py", line 119, in main
    create_ncs_dashboard_cm(
  File "/root/scripts/create_dashboard_cm.py", line 70, in create_ncs_dashboard_cm
    json_string = minify_json(input_file)
                  ^^^^^^^^^^^^^^^^^^^^^^^
  File "/root/scripts/create_dashboard_cm.py", line 24, in minify_json
    raise Exception(
Exception: Cannot find the JSON file for the NCS Dashboard. Reason: [Errno 2] No such file or directory: '/root/scripts/json-files/ncs_dashboard.json'
controlplane:~$ cd scripts/
controlplane:~/scripts$ cd json-files/
controlplane:~/scripts/json-files$ ;s
bash: syntax error near unexpected token `;'
controlplane:~/scripts/json-files$ ls
ncs-dashboard.json
controlplane:~/scripts/json-files$ mv ncs-dashboard.json ncs_dashboard.json
controlplane:~/scripts/json-files$ 
controlplane:~/scripts/json-files$ 
controlplane:~/scripts/json-files$ 
controlplane:~/scripts/json-files$ ls
ncs_dashboard.json
controlplane:~/scripts/json-files$ cd ../..
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ python3  /root/scripts/create_dashboard_cm.py &&  kubectl apply -f /root/scripts/yaml-files/ncs-dashboard-cm-minified.yaml --context arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-1apr
configmap/ncs-dashboard-configmap created
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ 
controlplane:~$ vi eks_inputs.env 
controlplane:~$ 
