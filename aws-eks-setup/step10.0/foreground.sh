#!/bin/bash

# Define the env file
ENV_FILE="eks_inputs.env"

# Keep asking until a valid primary_owner is entered
while true; do
    # Ask the user for the primary_owner value
    read -p "Enter the primary_owner value: " PRIMARY_OWNER

    # Check if the input is empty
    if [[ -z "$PRIMARY_OWNER" ]]; then
        echo "Error: primary_owner cannot be empty. Please enter a valid value."
    else
        # If the input is not empty, break the loop
        break
    fi
done

# Append the primary_owner value to the env file
echo "PRIMARY_OWNER=$PRIMARY_OWNER" >> "$ENV_FILE"

# Inform the user that the value has been set
echo "primary_owner has been set to: $PRIMARY_OWNER"

