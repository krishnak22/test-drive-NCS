# Deploying the NCS CLUSTER

**To deploy the NCS Cluster run the following command.**

`kubectl apply -f ncs-cr.yaml`{{exec}}

**Generally it takes 16 - 18 min to get into running state, to check the status run the following command.**

`kubectl get ncscluster $NCS_CLUSTER_NAME -n ncs-system -o wide`{{exec}}

**If it takes more than 18 min, check the logs by running the following command.**

`kubectl logs -f -n ncs-cluster-operator-system ncs-cluster-operator-controller-manager-0`{{exec}}
