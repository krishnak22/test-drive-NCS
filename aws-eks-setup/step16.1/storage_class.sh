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
