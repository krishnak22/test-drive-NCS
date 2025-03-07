curl -L -O https://github.com/nutanix/helm-releases/releases/download/nutanix-csi-storage-3.2.0/nutanix-csi-storage-3.2.0.tgz

tar -xvf nutanix-csi-storage-3.2.0.tgz

pip install ruamel.yaml

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

VIP=$(kubectl get ncscluster testdrive-ncs -n ncs-system -o jsonpath='{.metadata.annotations.vip}')
echo "VIP=$VIP" >> /root/eks_inputs.env

PASSWORD=$(kubectl get -n ncs-system secrets/testdrive-ncs-init-creds -ogo-template='{{index .data "cvm-creds" | base64decode}}' | base64 -d)
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
