#!/bin/bash

# Ask the user for the primary owner value
echo "Please enter the primary owner value:"
read primary_owner

# Add the primary owner value to the file
echo "PRIMARY_OWNER=$primary_owner" >> eks_inputs.env

# Confirm the addition
echo "Primary owner added to eks_inputs.env: PRIMARY_OWNER=$primary_owner"

