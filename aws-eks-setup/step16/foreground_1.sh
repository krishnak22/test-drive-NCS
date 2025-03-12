# Creating a Storage Class

cat << EOF > /root/sc.yaml
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
    name: base-sc
parameters: 
  csi.storage.k8s.io/controller-expand-secret-name: ntnx-secret
  csi.storage.k8s.io/controller-expand-secret-namespace: ntnx-system
  csi.storage.k8s.io/node-publish-secret-name: ntnx-secret
  csi.storage.k8s.io/node-publish-secret-namespace: ntnx-system
  csi.storage.k8s.io/provisioner-secret-name: ntnx-secret
  csi.storage.k8s.io/provisioner-secret-namespace: ntnx-system
  csi.storage.k8s.io/controller-publish-secret-name: ntnx-secret
  csi.storage.k8s.io/controller-publish-secret-namespace: ntnx-system
  csi.storage.k8s.io/fstype: ext4
  hypervisorAttached: DISABLED
  storageContainer: SelfServiceContainer
  storageType: NutanixVolumes
provisioner: csi.nutanix.com
reclaimPolicy: Delete 
EOF

kubectl apply -f sc.yaml

cat << EOF > /root/pvc.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
   name: postgresql-claim
spec:
   accessModes:
      - ReadWriteOnce
   resources:
      requests:
         storage: 10Gi
   storageClassName: base-sc
EOF

kubectl apply -f pvc.yaml

#Creating Config map
cat << EOF > /root/postgres-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  labels:
    app: postgres
data:
  POSTGRES_DB: postgresdb
  POSTGRES_USER: admin
  POSTGRES_PASSWORD: psltest
EOF

kubectl apply -f postgres-config.yaml

#Getting the node name 
get_node_by_cidr() {
    local target_cidr=$1
    local nodes=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    local IFS='.'
    
    for node in "${nodes[@]}"; do
        if [[ $node =~ ip-([0-9]+)-([0-9]+)-([0-9]+)-([0-9]+) ]]; then
            ip="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.${BASH_REMATCH[4]}"
            if ipcalc -c "$ip" "$target_cidr" 2>/dev/null; then
                echo "$node"
                return
            fi
        fi
    done
    
    echo "No matching node found"
}

source eks_inputs.env
target_cidr=$AOS_SUBNET_CIDR
matching_node=$(get_node_by_cidr "$target_cidr")
echo "AOS_NODE_NAME=$matching_node" >> eks_inputs.env

#Create Pod that will use the pvc
source eks_inputs.env
cat << EOF > /root/Pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: postgres  # Sets Deployment name
spec:
  nodeSelector:
    nodename: $AOS_NODE_NAME
  containers:
    - name: postgres
      image: postgres:10.1 # Sets Image
      imagePullPolicy: "IfNotPresent"
      ports:
        - containerPort: 5432  # Exposes container port
      envFrom:
        - configMapRef:
            name: postgres-config
      volumeMounts:
        - mountPath: /var/lib/postgresql/data/
          name: postgredb
          subPath: postgres
      resources:
        requests:
          cpu: 1m
          memory: 10Mi
        limits:
          cpu: 100m
          memory: 100Mi
  volumes:
    - name: postgredb
      persistentVolumeClaim:
        claimName: postgresql-claim



