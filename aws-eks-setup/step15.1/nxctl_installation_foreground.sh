aws ecr get-login-password --region us-west-2 | helm registry login  --username AWS --password-stdin 353502843997.dkr.ecr.us-west-2.amazonaws.com
helm pull oci://353502843997.dkr.ecr.us-west-2.amazonaws.com/ncs-nxctl --version 1.0.0-1132 --untar
rpm -qa | grep -q nxctl && rpm -e $(rpm -qa | grep nxctl) || true
sudo rpm -i /root/ncs-nxctl/files/nxctl*.rpm --nodeps
