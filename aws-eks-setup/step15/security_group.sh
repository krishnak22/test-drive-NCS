#!/bin/bash

kubectl get nodes -o wide | awk 'NR>1 {print $6}' | nl -v1 | awk '{print "node"$1"="$2}' >> eks_inputs.env

source eks_inputs.env

SECURITY_GROUP_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.resourcesVpcConfig.securityGroupIds[0]" --output text) >> eks_inputs.env

echo "SECURITY_GROUP_ID=$SECURITY_GROUP_ID" >> /root/eks_inputs.env

for key in $(compgen -A variable | grep 'node'); do
    IP=${!key} 

    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 22 \
        --cidr ${IP}/32
done
