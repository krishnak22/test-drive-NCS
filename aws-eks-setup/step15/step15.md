#  Installing the CSI Volume Driver

##  About this task
The CSI Volume Driver Helm Chart packages include the required deployment YAML manifests. To install the driver, perform the following tasks using Helm, the Kubernetes package management tool.

## STEP 1 :

**DOWNLOAD THE HELM CHART **

To download the **CSI Volume Driver Helm Chart** click on the following command to run it.

`curl -L -O https://github.com/nutanix/helm-releases/releases/download/nutanix-csi-storage-3.2.0/nutanix-csi-storage-3.2.0.tgz`{{exec}}

## STEP2 :

**Untar the Helm Chart file by clicking on the following command.**

`tar -xvf nutanix-csi-storage-3.2.0.tgz`{{exec}}

## STEP3 :

Retrieving the **prismEndpoint and password** of the PE

**STEP3.1 : ** To get the prismEndpoint execute the following command and use the vip as prsimEndpoint.

`Kubectl describe ncscluster testdrive-ncs -n ncs-system`{{exec}}

**STEP3.2 : ** To get the password execute the following command and use the output as password. 

`kubectl get -n ncs-system secrets/testdrive-ncs-init-creds -ogo-template='{{index .data "cvm-creds" | base64decode}}' | base64 -d`{{exec}}

## STEP4

Updating the values.yaml file in nutanix-csi-storage-3.2.0.tgz directory.

**STEP4.1 : ** Update the value of **createPrismCentralSecret** to false.
**STEP4.2 : ** Uncomment the **prismEndPoint, username, password** and update the values and use **admin** as username.
**STEP4.3 : ** Update the value of **usePC** as false.

## STEP5

**Install the CSI Volume Driver by executing the following command**

`helm install -n ntnx-system -f nutanix-csi-storage/values.yaml nutanix-csi ./nutanix-csi-storage`{{exec}}

## STEP 6

**Verify that the pods nutanix-csi-node and nutanix-csi-controller are running**

`kubectl get pod -n ntnx-system`{{exec}}

