#!/bin/bash

source eks_inputs.env
TARGET_DIR="/root"

cat <<EOF > "$TARGET_DIR/ntnx-secret.yaml"
apiVersion: v1
kind: Secret
metadata:
 name: ntnx-secret
 namespace: ntnx-system
data:
 key: $KEY
EOF

