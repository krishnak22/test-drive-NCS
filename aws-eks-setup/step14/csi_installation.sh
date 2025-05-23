curl -L -O https://github.com/nutanix/helm-releases/releases/download/nutanix-csi-storage-3.2.0/nutanix-csi-storage-3.2.0.tgz

tar -xvf nutanix-csi-storage-3.2.0.tgz

cat << EOF > "/root/py_script_1.py"
from ruamel.yaml import YAML
  
yaml = YAML()

with open("/root/nutanix-csi-storage/values.yaml", "r") as f:
    data = yaml.load(f)

data['ntnxInitConfigMap']['usePC'] = False
data['createPrismCentralSecret'] = False
data['createSecret']= False

with open("/root/nutanix-csi-storage/values.yaml", "w") as f:
    yaml.dump(data, f)
EOF

source eks_inputs.env
VIP=$(kubectl get ncscluster $NCS_CLUSTER_NAME -n ncs-system -o jsonpath='{.metadata.annotations.vip}')
echo "VIP=$VIP" >> /root/eks_inputs.env

source eks_inputs.env
PASSWORD=$(kubectl get -n ncs-system secrets/$NCS_CLUSTER_NAME-init-creds -ogo-template='{{index .data "cvm-creds" | base64decode}}' | base64 -d)
echo "PASSWORD=$PASSWORD" >> /root/eks_inputs.env

source eks_inputs.env
KEY=$(echo -n "$VIP:9440:admin:$PASSWORD" | base64)
echo "KEY=$KEY" >> /root/eks_inputs.env

python py_script_1.py
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

kubectl apply -f ntnx-secret.yaml

kubectl get nodes -o wide | awk 'NR>1 {print $6}' | nl -v1 | awk '{print "node"$1"="$2}' >> eks_inputs.env

source eks_inputs.env
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --region us-west-2 --filters "Name=tag:Name,Values=ncs-$NCS_CLUSTER_NAME-aos-external" --query "SecurityGroups[0].GroupId" --output text)
echo "SECURITY_GROUP_ID=$SECURITY_GROUP_ID" >> /root/eks_inputs.env

source eks_inputs.env
for key in $(compgen -A variable | grep 'node'); do
    IP=${!key}

    aws ec2 authorize-security-group-ingress \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 9440 \
        --cidr "${IP}/32" \
        --region "$REGION"
done


helm install -n ntnx-system -f nutanix-csi-storage/values.yaml nutanix-csi ./nutanix-csi-storage

kubectl get pod -n ntnx-system
