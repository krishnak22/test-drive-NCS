source eks_inputs.env

echo "WORKER_NODE_NAME=$CLUSTER_NAME-wn" >> eks_inputs.env
echo "NODE_POOL_NAME=$CLUSTER_NAME-np" >> eks_inputs.env
echo "NCS_CLUSTER_NAME=$CLUSTER_NAME-cn-aos-cl" >> eks_inputs.env
echo "NCS_INFRA_NAME=$CLUSTER_NAME-cn-aos-infra" >> eks_inputs.env
