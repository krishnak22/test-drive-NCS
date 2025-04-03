cat << EOF > /root/scripts/pre-files/prometheus_sc.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: prometheus-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  tagSpecification_1: primary_owner=${var.primary_owner}
  tagSpecification_2: ncs-cluster-name=${var.ncs_cluster_name}
volumeBindingMode: WaitForFirstConsumer
EOF

cat << EOF > /root/scripts/pre-files/prometheus_nodeport_service.yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    prometheus.io/port: "9090"
    prometheus.io/scrape: "true"
  name: prometheus-service
  namespace: monitoring
spec:
  ports:
    - nodePort: 30000
      port: 8080
      targetPort: 9090
  selector:
    prometheus: prometheus-kube-prometheus-prometheus
  type: NodePort
EOF


cat << EOF > /root/scripts/pre-files/load_balancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana-lb-service
  namespace: monitoring
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-subnets: $LB_SUBNET_ID
    service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: { \primary_owner\=\$PRIMARY_OWNER\, \ncs-cluster-name\=\$NCS_CLUSTER_NAME\ }
spec:
  type: LoadBalancer
  ports:
    - name: grafana-lb
      port: 3000
      targetPort: 3000
      protocol: TCP
  selector:
    app.kubernetes.io/name: grafana
  loadBalancerSourceRanges:
    - $USER_IP
EOF

cat << EOF > /root/scripts/pre-files/custom_exporter_service_monitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app: metadata-exporter
    release: prometheus
  name: metadata-exporter-monitor
  namespace: monitoring
spec:
  endpoints:
    - interval: 15s
      port: metrics
      scrapeTimeout: 10s
  selector:
    matchLabels:
      app: metadata-exporter
EOF

cat << EOF > /root/scripts/pre-files/aos_publisher_service.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    ncs/cluster-name: $NCS_CLUSTER_NAME
  name: aos-publisher-service
  namespace: ncs-system
spec:
  ports:
    - name: metrics
      port: 9000
      targetPort: 9000
  selector:
    ncs/cluster-name: $NCS_CLUSTER_NAME
EOF

cat << EOF > /root/scripts/pre-files/aos_publisher_service_monitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    ncs/cluster-name: $NCS_CLUSTER_NAME
    release: prometheus
  name: aos-publisher-service-monitor
  namespace: monitoring
spec:
  endpoints:
    - interval: 1s
      metricRelabelings:
        - sourceLabels:
            - volume_group_name
          targetLabel: volumename
      port: metrics
      scrapeTimeout: 1s
  namespaceSelector:
    matchNames:
      - ncs-system
  selector:
    matchLabels:
      ncs/cluster-name: $NCS_CLUSTER_NAME
EOF

cat << EOF > /root/scripts/pre-files/cloudwatch_exporter.yaml
resources:
  requests:
    cpu: "10m"
    memory: "200Mi"
  limits:
    cpu: "200m"
    memory: "4Gi"
aws:
  role: "${aws_iam_role.cloudwatch_exporter_role.name}"
config: |
  region: ${var.eks_cluster_region}
  period_seconds: 300
  metrics:
    - aws_namespace: AWS/EC2
      aws_metric_name: CPUUtilization
      aws_dimensions: [InstanceId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:instance"
        resource_id_dimension: InstanceId
      aws_statistics: [Average]
    - aws_namespace: AWS/EC2
      aws_metric_name: EBSReadBytes
      aws_dimensions: [InstanceId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:instance"
        resource_id_dimension: InstanceId
      aws_statistics: [Average]
    - aws_namespace: AWS/EC2
      aws_metric_name: EBSWriteBytes
      aws_dimensions: [InstanceId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:instance"
        resource_id_dimension: InstanceId
      aws_statistics: [Average]
    - aws_namespace: AWS/EC2
      aws_metric_name: DiskWriteBytes
      aws_dimensions: [InstanceId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:instance"
        resource_id_dimension: InstanceId
      aws_statistics: [Average]
    - aws_namespace: AWS/EC2
      aws_metric_name: DiskReadBytes
      aws_dimensions: [InstanceId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:instance"
        resource_id_dimension: InstanceId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeReadBytes
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeWriteBytes
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeReadOps
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeWriteOps
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeTotalReadTime
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeTotalWriteTime
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeIdleTime
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          eks:cluster-name: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeReadBytes
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          KubernetesCluster: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeWriteBytes
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          KubernetesCluster: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeReadOps
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          KubernetesCluster: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeWriteOps
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          KubernetesCluster: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeTotalReadTime
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          KubernetesCluster: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeTotalWriteTime
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          KubernetesCluster: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
    - aws_namespace: AWS/EBS
      aws_metric_name: VolumeIdleTime
      aws_dimensions: [VolumeId]
      aws_tag_select:
        tag_selections:
          KubernetesCluster: [${var.eks_cluster_name}]
        resource_type_selection: "ec2:volume"
        resource_id_dimension: VolumeId
      aws_statistics: [Average]
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "${aws_iam_role.cloudwatch_exporter_role.arn}"
  name: "cloudwatch-exporter-sa"
  namespace: "monitoring"
serviceMonitor:
  enabled: true
  interval: "300s"
  labels:
    release: "prometheus"
  telemetryPath: "/metrics"
  timeout: "30s"
EOF
