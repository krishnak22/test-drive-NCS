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
