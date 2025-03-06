source eks_inputs.env

KEY=$(echo -n "$VIP:9440:admin:$PASSWORD" | base64)

echo "KEY=$KEY" >> /root/eks_inputs.env
