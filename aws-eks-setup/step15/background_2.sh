#!/bin/bash

PYTHON_FILE="/root/py_script_1.py"

cat << EOF >> "/root/py_script_1.py"
from ruamel.yaml import YAML

with open("/root/nutanix-csi-storage/values.yaml", "r") as f:
    data = yaml.load(f)

data['ntnxInitConfigMap']['usePC'] = False

with open("file.yaml", "w") as f:
    yaml.dump(data, f)

EOF
