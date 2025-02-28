#!/bin/bash

# Prompt and collect inputs without validation
echo "Enter the NODE_COUNT:"
read -r NODE_COUNT
echo "NODE_COUNT=$NODE_COUNT" >> /root/eks_inputs.env

echo "Enter the AVAILABILITY_ZONE:"
read -r AVAILABILITY_ZONE
echo "AVAILABILITY_ZONE=$AVAILABILITY_ZONE" >> /root/eks_inputs.env

echo "Enter the INSTANCE_TYPE:"
read -r INSTANCE_TYPE
echo "INSTANCE_TYPE=$INSTANCE_TYPE" >> /root/eks_inputs.env

echo "Enter the AMI_TYPE:"
read -r AMI_TYPE
echo "AMI_TYPE=$AMI_TYPE" >> /root/eks_inputs.env

echo "Enter the AMI_RELEASE_VERSION:"
read -r AMI_RELEASE_VERSION
echo "AMI_RELEASE_VERSION=$AMI_RELEASE_VERSION" >> /root/eks_inputs.env

echo "Enter the SSH_KEY_PAIR:"
read -r SSH_KEY_PAIR
echo "SSH_KEY_PAIR=$SSH_KEY_PAIR" >> /root/eks_inputs.env

echo "Enter the SUBNET_CIDR:"
read -r SUBNET_CIDR
echo "SUBNET_CIDR=$SUBNET_CIDR" >> /root/eks_inputs.env

echo "Enter the NCS_CLUSTER_NAME:"
read -r NCS_CLUSTER_NAME
echo "NCS_CLUSTER_NAME=$NCS_CLUSTER_NAME" >> /root/eks_inputs.env

echo "Enter the AOS_SUBNET_CIDR:"
read -r AOS_SUBNET_CIDR
echo "AOS_SUBNET_CIDR=$AOS_SUBNET_CIDR" >> /root/eks_inputs.env

echo "Enter the VERSION:"
read -r VERSION
echo "VERSION=$VERSION" >> /root/eks_inputs.env

echo "All inputs have been successfully collected and saved in /root/eks_inputs.env"

