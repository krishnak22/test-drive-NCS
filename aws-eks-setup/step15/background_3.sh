VIP=$(kubectl get ncscluster testdrive-ncs -n ncs-system -o jsonpath='{.metadata.annotations.vip}')

PASSWORD=$(kubectl get -n ncs-system secrets/testdrive-ncs-init-creds -ogo-template='{{index .data "cvm-creds" | base64decode}}' | base64 -d)

echo "PASSWORD=$PASSWORD" >> /root/eks_inputs.env
echo "VIP=$VIP" >> /root/eks_inputs.env
