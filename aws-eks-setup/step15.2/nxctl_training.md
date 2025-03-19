# NXCTL TRAINING

This training will help you get familiar with the commands available in our CLI. Follow the steps below to explore its functionalities.

**To view the available commands and their descriptions, run:**  

`nxctl --help`{{exec}}

## NXCTL CLUSTER COMMAND

**The nxctl cluster command allows you to manage and manipulate CN-AOS clusters. To see the available operations, run:**  

`nxctl cluster --help`{{exec}}  

**To list all CN-AOS Clusters from given namespace. If no namespace is provided then ncs-system is used.**  

`nxctl cluster list`{{help}}

**To get the details of CN-AOS Cluster. Cluster Name should bepassed in the command arguments. The details include ClusterName, ClusterIP, number of nodes etc.**  

`nxctl cluster info $NCS_CLUSTER_NAME`{{exec}}

**To list all CN-AOS System pods across namespaces and worker nodes.**   

`nxctl cluster pods $NCS_CLUSTER_NAME`{{exec}}  

**To list ingress rules from AOS security group of given cluster.**

`nxctl cluster aos-security-group list-rules $NCS_CLUSTER_NAME`{{exec}}

### NXCTL CLUSTER MANIPULATION COMMANDS

**These commands take time to execute, so we will run them with the --help flag for training purposes. This will give us an understanding of what each command does.**

#### NXCTL CLUSTER STOP 

**Stop command stops the requested CN-AOS Cluster.**

`nxctl cluster stop --help`{{exec}}

#### NXCTL CLUSTER START

**This command starts the CN-AOS cluster which was previously stopped using Cluster Stop command.**

`nxctl cluster start --help`{{exec}}

#### NXCTL CLUSTER ADD DISK

**Performs the add-disk operation on the CN-AOS cluster.**

`nxctl cluster add-disk --help`{{exec}}

#### NXCTL CLUSTER DESTROY

**Permanently destroy the CN-AOS Cluster.**

`nxctl cluster destroy --help`{{exec}}

#### NXCTL CLUSTER EXPAND

**Increase the node-count to the specified number.**

`nxctl cluster expland --help`

#### NXCTL CLUSTER REMOVE NODE

**Performs remove node operation on the CN-AOS cluster.**  

`nxctl cluster remove-node --help`{{execute}}

