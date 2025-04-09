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
          "$OIDC_PROVIDER:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
source eks_inputs.env
aws iam create-role --role-name $CLUSTER_NAME-cw-grafana-role --assume-role-policy-document file://trust_policy.json
aws iam attach-role-policy --role-name $CLUSTER_NAME-cw-grafana-role --policy-arn arn:aws:iam::353502843997:policy/cn-aos-td-cw-grafana-policy
rm trust_policy.json
source eks_inputs.env
CW_ROLE_ARN=$(aws iam get-role --role-name "$CLUSTER_NAME-cw-grafana-role" --region $REGION --query "Role.Arn" --output text)
echo "CW_ROLE=$CW_ROLE_ARN" >> /root/eks_inputs.env

eksctl create iamserviceaccount --cluster "$CLUSTER_NAME" --region "$REGION" --name ncs-infra-sa-new-2 --namespace ncs-infra-deployment-operator-system --attach-policy-arn arn:aws:iam::353502843997:policy/test-drive-ncs-bf-op-policy-1 --approve
