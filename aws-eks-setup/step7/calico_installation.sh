source eks_inputs.env

echo -e "\nInstalling Calico on EKS cluster '$CLUSTER_NAME'..."

kubectl delete daemonset -n kube-system aws-node

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/tigera-operator.yaml

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
