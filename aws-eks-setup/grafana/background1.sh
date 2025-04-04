helm repo add prometheus-community https://prometheus-community.github.io/helm-charts -n monitoring 
helm repo update

kubectl apply -f /root/scripts/pre-files/prometheus_sc.yaml --context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr

helm install -f  /root/scripts/yaml-files/kube-prometheus-stack-values.yaml  prometheus prometheus-community/kube-prometheus-stack --kube-context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr -n monitoring --version 60.0.1

kubectl apply -f /root/scripts/pre-files/prometheus_nodeport_service.yaml --context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr

python3 /root/scripts/create_dashboard_cm.py && kubectl apply -f /root/scripts/yaml-files/ncs-dashboard-cm-minified.yaml --context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr

kubectl apply -f /root/scripts/pre-files/custom_exporter_service_monitor.yaml --context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr

kubectl apply -f /root/scripts/pre-files/aos_publisher_service.yaml --context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr

kubectl apply -f /root/scripts/pre-files/aos_publisher_service_monitor.yaml --context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr

kubectl apply -f /root/scripts/pre-files/load_balancer.yaml --context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr

eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $REGION --name cloudwatch-exporter-sa --namespace monitoring --attach-policy-arn arn:aws:iam::353502843997:policy/cn-aos-td-cw-grafana-policy --approve

source eks_inputs.env
OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.identity.oidc.issuer" --output text | sed 's#https://##')
cat <<EOF > trust_policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::353502843997:oidc-provider/$OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_PROVIDER:sub": "system:serviceaccount:monitoring:cloudwatch-exporter-sa",
          "$OIDC_PROVIDER_URL_FORMATTED:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Create the IAM role
aws iam create-role --role-name cn-aos-td-cw-grafana-role --assume-role-policy-document file://trust_policy.json

# Clean up
rm trust_policy.json

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.Arn" --output text)
echo "CW_ROLE=$ROLE_ARN" >> /root/eks_inputs.env

helm install -f /root/scripts/pre-files/cloudwatch_exporter.yaml cloudwatch-exporter prometheus-community/prometheus-cloudwatch-exporter --kube-context=arn:aws:eks:us-west-2:353502843997:cluster/ktd-ncs-3apr  -n monitoring --version 0.25.3
