#!/bin/bash

# Define the env file
ENV_FILE="eks_inputs.env"

# Keep asking until a valid primary_owner is entered
while [[ -z "$PRIMARY_OWNER" ]]; do
    read -p "Enter the primary_owner value: " PRIMARY_OWNER
done

# Append primary_owner to the env file
echo "PRIMARY_OWNER=$PRIMARY_OWNER" >> "$ENV_FILE"

echo "primary_owner has been set to: $PRIMARY_OWNER"

