source eks_inputs.env

KEY=$(echo -n "$VIP:9440:admin:$PASSWORD" | base64) >> /root/eks_inputs.env
