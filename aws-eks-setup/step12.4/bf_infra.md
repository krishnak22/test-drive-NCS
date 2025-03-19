# Setting up the Infra

**To start the infra deployment run the following command.**

`kubectl apply -f bf-infra.yaml`{{exec}}

**To check the status of infra deployment, run the following command.**  

`kubectl describe ncsinfra $NCS_INFRA_NAME -n ncs-infra-deployment-operator-system`{{exec}}  

**Generally it takes 7-8 min for this to get deployed, if it takes more then check the logs.**

`kubectl logs -f -n ncs-infra-deployment-operator-system   ncs-infra-deployment-operator-controller-manager`{{exec}}
