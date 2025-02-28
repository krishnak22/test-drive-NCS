#!/bin/bash

# Function to clean input (remove carriage return characters)
clean_input() {
    echo "$1" | tr -d '\r'
}

while true; do
    # Ask the user for the primary owner value
    echo "Please enter the primary owner value:"
    read -r primary_owner

    # Clean the input to remove any carriage return characters
    primary_owner=$(clean_input "$primary_owner")

    # Check if the input is not empty
    if [[ -z "$primary_owner" ]]; then
        echo "Error: Primary owner value cannot be empty. Please enter a valid value."
        continue
    fi

    # Add the primary owner value to the /root/eks_inputs.env file
    echo "PRIMARY_OWNER=$primary_owner" >> /root/eks_inputs.env
    break
done

