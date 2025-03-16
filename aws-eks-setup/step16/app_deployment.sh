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

mapfile -t nodes < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name} {.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
source eks_inputs.env
subnet_cidr=$SUBNET_CIDR
subnet_prefix=$(echo "$subnet_cidr" | cut -d'.' -f1-3)
for node in "${nodes[@]}"; do
    node_name=$(echo "$node" | awk '{print $1}')
    node_ip=$(echo "$node" | awk '{print $2}')

    if [[ -z "$node_ip" ]]; then
        continue
    fi

    if [[ "$node_ip" == $subnet_prefix.* ]]; then
        echo "Match found: Node $node_name with IP $node_ip matches subnet $subnet_cidr"
        echo "SCHEDULER_NODE=$node_name" >> eks_inputs.env
        break
    fi
done

source eks_inputs.env
cat << EOF > /root/Pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: postgres  # Sets Deployment name
spec:
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
  nodeName: $SCHEDULER_NODE
  volumes:
    - name: postgredb
      persistentVolumeClaim:
        claimName: postgresql-claim
EOF

kubectl apply -f Pod.yaml

kubectl get pod postgres

