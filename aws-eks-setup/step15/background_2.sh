#!/bin/bash

PYTHON_FILE="/root/py_script_1.py"

cat << EOF >> "/root/py_script_1.py"
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


