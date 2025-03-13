helm delete nutanix-csi -n ntnx-system

kubectl delete ncscluster testdrive-ncs -n ncs-system

kubectl delete ncsinfra $NCS_INFRA_NAME -n $SERVICE_ACCOUNT_NAMESPACE

kubectl delete workernode $WORKERNODE_NAME -n $SERVICE_ACCOUNT_NAMESPACE

kubectl delete CustomResourceDefinition ncsinfras.ncs.nutanix.com

kubectl delete sa $SERVICE_ACCOUNT_NAME -n $SERVICE_ACCOUNT_NAMESPACE

OIDC_ISSUER_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')
if [ "$OIDC_ISSUER_URL" == "None" ]; then
  echo "No OIDC provider found for this cluster. Exiting."
fi
OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, '$OIDC_ISSUER_URL')].Arn" --output text)

if [ -z "$OIDC_PROVIDER_ARN" ]; then
  echo "OIDC provider not found. It may have already been deleted."
else
  echo "Deleting OIDC provider: $OIDC_PROVIDER_ARN"
  aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN"
  echo "OIDC provider deleted successfully."
fi

eksctl delete nodegroup --cluster $CLUSTER_NAME --name td-ncs-ng-1

eksctl delete cluster --name $CLUSTER_NAME --region $REGION
