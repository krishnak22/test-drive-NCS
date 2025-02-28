#!/bin/bash

# Ask the user for the primary owner value
echo "Please enter the primary owner value:"
read primary_owner

# Add the primary owner value to the /root/eks_inputs.env file
echo "PRIMARY_OWNER=$primary_owner" >> /root/eks_inputs.env

# Confirm that the value has been added
echo "Primary owner value has been added to /root/eks_inputs.env: PRIMARY_OWNER=$primary_owner"

