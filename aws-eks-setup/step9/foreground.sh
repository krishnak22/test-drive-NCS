#!/bin/bash
# create-nodegroup-yaml.sh
# This script reads cluster details from eke-setup.env and generates a YAML file for creating a private node group.


# Source the environment variables
source eks_inputs.env

# Name of the output YAML file
OUTPUT_FILE="nodegroup.yaml"

# Create the YAML file with the basic structure
cat > "$OUTPUT_FILE" <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}
nodeGroups:
  - name: private-ng
    instanceType: t3.medium
    desiredCapacity: 2
    privateNetworking: true
    subnets:
EOF

# Convert the comma-separated subnet list into YAML list items
IFS=',' read -ra SUBNET_ARRAY <<< "$SUBNET_IDS"
for subnet in "\${SUBNET_ARRAY[@]}"; do
  # Remove any accidental spaces around subnet IDs
  subnet=\$(echo "\$subnet" | xargs)
  echo "      - ${subnet}" >> "$OUTPUT_FILE"
done

echo "YAML file '$OUTPUT_FILE' created successfully."

