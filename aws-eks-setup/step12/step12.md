`kubectl apply -f bf-operator.yaml`{{exec}}

`kubectl apply -f bf-nodegroup.yaml`{{exec}}

`kubectl logs -f -n ncs-infra-deployment-operator-system   ncs-infra-deployment-operator-controller-manager`{{exec}}

`source eks_inputs.env \
 kubectl describe workernode $WORKER_NODE_NAME -n ncs-infra-deployment-operator-system`{{exec}}

`kubectl apply -f bf-infra.yaml`{{exec}}

`source eks_inputs.env \
 kubectl describe ncsinfra $NCS_INFRA_NAME -n ncs-infra-deployment-operator-system`{{exec}}

`kubectl apply -f ncs-cr.yaml`{{exec}}

`kubectl logs -f -n ncs-cluster-operator-system ncs-cluster-operator-controller-manager-0`{{exec}}

`source eks_inputs.env \
 kubectl describe ncscluster testdrive-ncs -n ncs-system`{{exec}}
