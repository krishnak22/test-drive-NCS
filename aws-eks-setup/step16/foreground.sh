#GET THE LOAD BALANCER READY
kubectl patch service nxctl-svc -n ncs-system --type='merge' -p '{
  "metadata": {
    "annotations": {
      "service.beta.kubernetes.io/aws-load-balancer-scheme": "internet-facing"
    }
  },
  "spec": {
    "ports": [
      {
        "port": 443,
        "protocol": "TCP",
        "targetPort": 6869
      }
    ]
  }
}'

BASE_URL=$(kubectl get svc nxctl-svc -n ncs-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "BASE_URL=$BASE_URL" >> eks_inputs.env

# Update the tls certificate
kubectl patch cert nxctl-tls -n ncs-system --type='merge' -p "{
  \"spec\": {
    \"dnsNames\": [
      \"$BASE_URL\",
      \"nxctl-svc.ncs-system.svc.cluster.local\"
    ]
  }
}"


# DELETE THE POD
POD_NAME=$(kubectl get pods -n ncs-system --no-headers -o custom-columns=":metadata.name" | grep "^nxctl-svc" | head -n 1)
echo "POD_NAME=$POD_NAME" >> /root/eks_inputs.env
source eks_inputs.env
kubectl delete pod $POD_NAME -n ncs-system

CA_CERT=$(kubectl get secret nxctl-tls-secret -n ncs-system -o jsonpath='{.data.ca\.crt}')
echo "CA_CERT=$CA_CERT" >> eks_inputs.env

#GETTING .nxctlconfig file ready
source eks_inputs.env
cat << EOF > /root/.nxctlconfig
version: 1737546277
nxctl_servers:
- name: $CLUSTER_NAME
  base_url: https://$BASE_URL:443
  region: $REGION
  default_namespace: ncs-system
  ca_cert: $CA_CERT
current_context: $CLUSTER_NAME
EOF

aws ecr get-login-password --region us-west-2 | helm registry login  --username AWS --password-stdin 353502843997.dkr.ecr.us-west-2.amazonaws.com
helm pull oci://353502843997.dkr.ecr.us-west-2.amazonaws.com/ncs-nxctl --version 1.0.0-1132 --untar
apt install -y rpm
rpm -qa | grep -q nxctl && rpm -e $(rpm -qa | grep nxctl) || true
sudo rpm -i /root/ncs-nxctl/files/nxctl*.rpm --nodeps
