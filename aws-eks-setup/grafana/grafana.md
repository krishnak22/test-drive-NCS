### Once the script has been successfully executed, the Grafana access link will be displayed on the screen. In the future, if you need to access the Grafana link again, simply run the following command:

`source eks_inputs.env`{{exec}}  

`echo $GRAFANA_LINK`{{exec}}  
#### OR  
### Grafana URL can also be retrieved through this nxctl command:
`nxctl cluster info $NCS_CLUSTER_NAME`{{exec}}

### CREDENTIALS FOR ACCESSING GRAFANA   
#### USERNAME: admin
#### PASSWORD: prom-operator
