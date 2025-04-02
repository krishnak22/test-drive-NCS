helm repo add prometheus-community https://prometheus-community.github.io/helm-charts -n monitoring 

source eks_inputs.env
PROMETHEUS_SC=$(cat <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: prometheus-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
EOF
)

kubectl apply -f PROMETHEUS_SC --context $CLUSTER_NAME
helm install -f ${path.module}/scripts/yaml-files/kube-prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack --kube-context=${local.eks_cluster_arn} -n monitoring --version ${local.prometheus_helm_chart_version}
