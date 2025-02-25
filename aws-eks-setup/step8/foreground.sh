source eks_inputs.env

echo -e "\n🚀 Installing Calico on EKS cluster '$CLUSTER_NAME'..."

# Step 3.1: Remove AWS VPC CNI Daemonset
kubectl delete daemonset -n kube-system aws-node

# Step 3.2: Install the Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/tigera-operator.yaml

# Step 3.3: Configure Calico installation
kubectl create -f - <<EOF
kind: Installation
apiVersion: operator.tigera.io/v1
metadata:
  name: default
spec:
  kubernetesProvider: EKS
  cni:
    type: Calico
  calicoNetwork:
    bgp: Disabled
EOF

# Step 3.4: Add nodes to the cluster
eksctl create nodegroup --cluster "$CLUSTER_NAME" --node-type t3.medium --region "$REGION"

