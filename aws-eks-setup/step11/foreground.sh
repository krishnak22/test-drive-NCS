source eks_inputs.env

eksctl create iamserviceaccount --cluster "$CLUSTER_NAME" --region "$REGION" --name ncs-infra-sa-new-2 --namespace ncs-infra-deployment-operator-system --attach-policy-arn arn:aws:iam::353502843997:policy/krishna-test-drive-ncs-bf-operator-policy,arn:aws:iam::353502843997:policy/krishna-test-drive-ncs-bf-operator-policy-2

 
echo "SERVICE_ACCOUNT_NAME=ncs-infra-sa-new-2" >> eks_inputs.env
echo "OPERATOR_NAMESPACE=ncs-infra-deployment-operator-system" >> eks_inputs.env
 
echo "Service account name and namespace have been added to eks_inputs.env" 
