#!/bin/bash

# Initialize the variables
declare -A inputs=(
  [WORKER_NODE_NAME]=""
  [NODE_POOL_NAME]=""
  [NODE_COUNT]=""
  [AVAILABILITY_ZONE]=""
  [INSTANCE_TYPE]=""
  [AMI_TYPE]=""
  [AMI_RELEASE_VERSION]=""
  [SSH_KEY_PAIR]=""
  [SUBNET_CIDR]=""
  [NCS_INFRA_NAME]=""
  [NCS_CLUSTER_NAME]=""
  [REPLICATION_FACTOR]=""
  [AOS_SUBNET_CIDR]=""
  [VERSION]=""
)

# Path to store the environment variables
env_file="file1.env"

# While loop for input
while true; do
  all_inputs_valid=true

  # Loop through each variable to get input from the user
  for var in "${!inputs[@]}"; do
    # Prompt for user input
    read -p "Enter value for $var: " input_value

    # Validate if input is not empty
    if [[ -z "$input_value" ]]; then
      echo "$var cannot be empty. Please provide a valid value."
      all_inputs_valid=false
      break
    else
      # Store the input in the array
      inputs[$var]="$input_value"
    fi
  done

  # If all inputs are valid, break out of the loop
  if [ "$all_inputs_valid" = true ]; then
    break
  fi
done

# Write the validated inputs to the file
> "$env_file"  # Clear the contents of the file (if it exists)
for var in "${!inputs[@]}"; do
  echo "$var=${inputs[$var]}" >> "$env_file"
done

echo "All inputs are valid. Values have been written to $env_file"

