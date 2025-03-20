# Creating the Nodegroup

**In this step we are going to apply the cn-aos-nodegroup.yaml, this will initiate the process of cretaing nodegroup.**

**To apply the cn-aos-nodegroup.yaml, run the following command.**

`kubectl apply -f cn-aos-nodegroup.yaml`{{exec}}

**The execution generally takes 3-4 min, check the nodes status by running the following command.**

`kubectl describe workernode $WORKER_NODE_NAME -n ncs-infra-deployment-operator-system`{{exec}}

**If it takes more than 4 min, check logs..**

`kubectl logs -f -n ncs-infra-deployment-operator-system   ncs-infra-deployment-operator-controller-manager`{{exec}}
