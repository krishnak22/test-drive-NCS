#!/bin/bash

# Print a message to prompt the user for input
echo "ENTER THE FOLLOWING DETAILS"

# Ask the user for the values and store them in variables
read -p "NODE_COUNT: " NODE_COUNT
read -p "AVAILABILITY_ZONE: " AVAILABILITY_ZONE
read -p "INSTANCE_TYPE: " INSTANCE_TYPE
read -p "AMI_TYPE: " AMI_TYPE
read -p "AMI_RELEASE_VERSION: " AMI_RELEASE_VERSION
read -p "SSH-KEY-PAIR: " SSH_KEY_PAIR
read -p "SUBNET_CIDR: " SUBNET_CIDR
read -p "NCS_CLUSTER_NAME: " NCS_CLUSTER_NAME
read -p "AOS_SUBNET_CIDR: " AOS_SUBNET_CIDR
read -p "VERSION: " VERSION

# Append the values to the eks_inputs.env file
echo "NODE_COUNT=$NODE_COUNT" >> eks_inputs.env
echo "AVAILABILITY_ZONE=$AVAILABILITY_ZONE" >> eks_inputs.env
echo "INSTANCE_TYPE=$INSTANCE_TYPE" >> eks_inputs.env
echo "AMI_TYPE=$AMI_TYPE" >> eks_inputs.env
echo "AMI_RELEASE_VERSION=$AMI_RELEASE_VERSION" >> eks_inputs.env
echo "SSH_KEY_PAIR=$SSH_KEY_PAIR" >> eks_inputs.env
echo "SUBNET_CIDR=$SUBNET_CIDR" >> eks_inputs.env
echo "NCS_CLUSTER_NAME=$NCS_CLUSTER_NAME" >> eks_inputs.env
echo "AOS_SUBNET_CIDR=$AOS_SUBNET_CIDR" >> eks_inputs.env
echo "VERSION=$VERSION" >> eks_inputs.env

echo "Values have been successfully added to eks_inputs.env!"

