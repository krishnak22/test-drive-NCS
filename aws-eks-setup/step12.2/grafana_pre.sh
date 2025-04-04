base_dir="scripts"
subdirs=("yaml-files" "json-files" "pre-files")

mkdir -p "$base_dir"

for subdir in "${subdirs[@]}"; do
  mkdir -p "$base_dir/$subdir"
done

cat << EOF > /root/scripts/create_dashboard_cm.py
# Description: Script to create a ConfigMap for the NCS Dashboard from the JSON Input File
import json
import os

import yaml
from config import logger


def minify_json(input_file):
    """
    Load JSON from a file and return as minified string

    Parameters:
    input_file (str): The path to the JSON file for the Dashboard
    """

    # Load the Input Dashboard JSON File and Convert to Minified JSON String
    try:
        with open(input_file, "r") as file:
            json_data = json.load(file)
            return json.dumps(json_data, separators=(",", ":"))
    except FileNotFoundError as error:
        logger.error("File %s not found", input_file)
        raise Exception(
            f"Cannot find the JSON file for the NCS Dashboard. Reason: {error}"
        ) from error
    except json.JSONDecodeError as json_error:
        logger.error("Invalid JSON in file %s", input_file)
        raise Exception(
            f"Invalid JSON in file {input_file}. Reason: {json_error}"
        ) from json_error


def create_configmap_dict(name, namespace, json_string):
    """
    Create a ConfigMap Dictionary given the JSON string

    Parameters:
    name (str): The name of the ConfigMap
    namespace (str): The namespace of the ConfigMap
    json_string (str): The JSON string to be stored in the ConfigMap
    """

    config_map_dict = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": name,
            "namespace": namespace,
            "labels": {"grafana_dashboard": "1"},
        },
        "data": {"ncs-dashboard.json": json_string},
    }

    return config_map_dict


def create_ncs_dashboard_cm(name, namespace, input_file, output_file):
    """
    Create a ConfigMap for the NCS Dashboard from the JSON Input File

    Parameters:
    name (str): The name of the ConfigMap
    namespace (str): The namespace of the ConfigMap
    input_file (str): The path to the JSON file for the Dashboard
    output_file (str): The path to the output YAML file for the ConfigMap
    """

    # Get the Minified JSON String
    json_string = minify_json(input_file)

    # Get the ConfigMap Dictionary
    config_map_dict = create_configmap_dict(name, namespace, json_string)

    # Parse the ConfigMap Dictionary to YAML
    try:
        yaml_content = yaml.dump(config_map_dict, sort_keys=False)
    except yaml.YAMLError as yaml_error:
        logger.error(
            "Error in parsing the ConfigMap Dictionary to YAML: %s", yaml_error
        )
        raise Exception(
            f"Error in parsing the ConfigMap Dictionary to YAML: {yaml_error}"
        ) from yaml_error

    # Create the ConfigMap YAML File
    try:
        with open(output_file, "w") as file:
            file.write(yaml_content)
    except IOError as io_error:
        logger.error(
            "Error in writing the ConfigMap YAML File: %s", output_file
        )
        raise Exception(
            f"Error in writing the ConfigMap YAML File: {output_file}. Reason: {io_error}"
        ) from io_error


def main():
    """
    Entry point of the script.
    Parses the JSON File and Creates the ConfigMap
    """
    # Get the Current Working Directory
    current_working_directory = os.path.dirname(__file__)
    # Get the Directory of the NCS Dashboard JSON File
    ncs_dashboard_json_file = os.path.join(
        current_working_directory, "json-files", "ncs_dashboard.json"
    )
    # Get the Directory of the NCS Dashboard ConfigMap YAML File
    ncs_dashboard_cm_yaml = os.path.join(
        current_working_directory,
        "yaml-files",
        "ncs-dashboard-cm-minified.yaml",
    )

    # Create the ConfigMap for the NCS Dashboard
    logger.info("Creating ConfigMap for NCS Dashboard")
    create_ncs_dashboard_cm(
        "ncs-dashboard-configmap",
        "monitoring",
        ncs_dashboard_json_file,
        ncs_dashboard_cm_yaml,
    )
    logger.info("ConfigMap for NCS Dashboard created successfully")


if __name__ == "__main__":
    main()

EOF


cat << EOF > /root/scripts/config.py
"""
This module contains the configuration for the logging module.
"""
import logging
import os

# Create a logger object.
logger = logging.getLogger(__name__)

# Set the level of this logger.
# DEBUG is the lowest level,
# #meaning that all messages of level DEBUG and above will be logged.
logger.setLevel(logging.DEBUG)

# Create a file handler that logs debug and higher
#  level log messages to a file.

try:
    file_handler = logging.FileHandler("/opt/nutanix/ncs/deployment.log")
except FileNotFoundError as file_handler_exception:
    file_handler = logging.FileHandler(os.environ["HOME"] + "/deployment.log")

file_handler.setLevel(logging.DEBUG)

# Create a formatter and add it to the handlers.
formatter = logging.Formatter(
    "[%(asctime)s] p%(process)s {%(pathname)s:%(lineno)d} %(levelname)s - %(message)s",
    "%m-%d %H:%M:%S",
)
file_handler.setFormatter(formatter)

# Add the file handler to the logger
logger.addHandler(file_handler)
EOF

cat << EOF > /root/scripts/yaml-files/grafana-deploy.yaml
# This file is used as for overriding helm chart values for grafana deployment
grafana:
  enabled: true
  defaultDashboardsEnabled: false
  persistence:
    enabled: true
    type: pvc
    storageClassName: prometheus-sc
    accessModes: ["ReadWriteOnce"]
    size: 15Gi
  sidecar:
    resources:
      requests:
        memory: 100Mi
        cpu: 1m
      limits:
        memory: 500Mi
        cpu: 40m
  additionalDataSources:
  - name: Loki
    type: loki
    url: http://loki-loki-distributed-query-frontend.monitoring:3100
  resources:
    requests:
      memory: 250Mi
      cpu: 10m
    limits:
      memory: 1.5Gi
      cpu: 200m
EOF

cat << EOF > /root/scripts/deploy_grafana
#!/usr/bin/env python3
"""
Script to deploy Grafana on EKS Cluster.
"""
import argparse
import os

from terraform_utils import (
    parse_terraform_vars_to_str,
    run_terraform_command,
    validate_cidr,
    get_ncs_cluster_name,
    get_ncs_cluster_primary_owner
)


def main():
    """
    Entry point of the script.
    Parses the input data, gets the workspace name and
    runs the terraform apply command with the variables.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--eks_cluster_name", help="Name of EKS Cluster", required=True
    )
    parser.add_argument(
        "--eks_cluster_region", help="Region of EKS Cluster", required=True
    )
    parser.add_argument(
        "--user_ip_cidr", help="User IP CIDR to access Grafana", required=True
    )
    args = parser.parse_args()
    workspace_name = get_ncs_cluster_name(
        args.eks_cluster_name, args.eks_cluster_region
    )

    is_valid_cidr = validate_cidr(args.user_ip_cidr)
    if not is_valid_cidr:
        print("Invalid CIDR provided. Please provide a valid CIDR.")
        return 1

    terraform_vars = {
        "eks_cluster_region": args.eks_cluster_region,
        "eks_cluster_name": args.eks_cluster_name,
        "user_ip_cidr": args.user_ip_cidr,
        "primary_owner": get_ncs_cluster_primary_owner(
            args.eks_cluster_name, args.eks_cluster_region
        ),
        "ncs_cluster_name": get_ncs_cluster_name(
            args.eks_cluster_name, args.eks_cluster_region
        ),
    }
    terraform_vars_str = parse_terraform_vars_to_str(terraform_vars)

    run_terraform_command(
        f"terraform -chdir={os.path.dirname(os.path.realpath(__file__))}/../../ apply  -auto-approve -no-color",
        terraform_vars_str,
        workspace_name,
    )


if __name__ == "__main__":
    main()
EOF

cat << EOF > /root/scripts/destroy_grafana
#!/usr/bin/env python3
"""
Script to destroy Grafana on EKS Cluster.
"""
import argparse
import os

from terraform_utils import (
    get_ncs_cluster_name,
    parse_terraform_vars_to_str,
    run_terraform_command,
)


def main():
    """
    Entry point of the script.
    Parses the input data, gets the workspace name and
    runs the terraform destroy command with the variables.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--eks_cluster_name", help="Name of EKS Cluster", required=True
    )
    parser.add_argument(
        "--eks_cluster_region", help="Region of EKS Cluster", required=True
    )
    args = parser.parse_args()
    workspace_name = get_ncs_cluster_name(
        args.eks_cluster_name, args.eks_cluster_region
    )

    terraform_vars = {
        "eks_cluster_region": args.eks_cluster_region,
        "eks_cluster_name": args.eks_cluster_name,
        "user_ip_cidr": "",
        "primary_owner": "",
        "ncs_cluster_name": "",
    }
    terraform_vars_str = parse_terraform_vars_to_str(terraform_vars)

    run_terraform_command(
        f"terraform -chdir={os.path.dirname(os.path.realpath(__file__))}/../../ destroy  -auto-approve -no-color",
        terraform_vars_str,
        workspace_name,
    )


if __name__ == "__main__":
    main()
EOF

cat << EOF > /root/scripts/yaml-files/grafana-destroy.yaml
# This file is used as for overriding helm chart values to uninstall grafana
grafana:
  enabled: false
EOF

cat << EOF > /root/scripts/yaml-files/kube-prometheus-stack-values.yaml
# For overriding default values of kube-prometheus-stack helm chart

defaultRules:
  create: false

additionalPrometheusRulesMap:
  rule-name:
    groups:
    - name: grafana-dashboard-rules
      rules:
      - record: cluster:cluster_cpu_usage:sum_ratio_rate
        expr: sum(rate(node_cpu_seconds_total{mode!~"idle|iowait|steal"}[2m]))/sum(machine_cpu_cores)
      - record: cluster:cluster_memory_usage:sum_ratio
        expr: sum(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / sum(node_memory_MemTotal_bytes)
      - record: cluster:cluster_disk_usage:sum_ratio
        expr: (sum (node_filesystem_size_bytes) - sum (node_filesystem_free_bytes)) / sum (node_filesystem_size_bytes)
      - record: cluster:cluster_disk_read_bytes:sum_ratio
        expr: sum by(device, instance) (rate(node_disk_read_bytes_total[2m]))
      - record: cluster:cluster_disk_write:sum_ratio 
        expr: sum by(device, instance) (rate(node_disk_written_bytes_total[2m]))
      - record: cluster:cpu_usage_trend:sum_rate
        expr: avg(sum by (instance, cpu) (rate(node_cpu_seconds_total{mode!~"idle|iowait|steal"}[2m])))
      - record: cluster:memory_usage_trend:sum
        expr: sum(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / sum(node_memory_MemTotal_bytes)
      - record: cluster:disk_read_trend:sum_rate
        expr: sum by(device, instance) (rate(node_disk_read_bytes_total[2m]))
      - record: cluster:disk_write_trend:sum_rate
        expr: sum by(device, instance) (rate(node_disk_written_bytes_total[2m]))
      - record: instance:node_cpu_usage:avg_sum_ratio
        expr: avg(sum by (instance, cpu) (rate(node_cpu_seconds_total{mode!~"idle|iowait|steal"}[2m]))) by (instance)
      - record: instance:node_memory_usage:sum
        expr: sum(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) by (instance)
      - record: instance:node_network_receive_bytes:sum_rate
        expr: sum by (instance) (rate(node_network_receive_bytes_total[2m]))
      - record: instance:node_network_transmit_bytes:sum_rate
        expr: sum by(instance) (rate(node_network_transmit_bytes_total[2m]))
      - record: instance:node_disk_read_rate:sum_rate
        expr: rate(node_disk_read_bytes_total{device=~"(/dev/)?(mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|md.+|dasd.+)"}[2m])
      - record: instance:node_disk_write_rate:sum_rate
        expr: rate(node_disk_written_bytes_total{device=~"(/dev/)?(mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|md.+|dasd.+)"}[2m])
      - record: container:pod_cpu_usage:sum_ratio_rate
        expr: sum(rate(container_cpu_usage_seconds_total{image!=""}[2m])) by (pod, namespace, node)
      - record: container:pod_memory_usage:sum_ratio
        expr: sum(container_memory_usage_bytes{image!=""}) by (pod, namespace, node)
      - record: container:pod_receive_bytes:sum_rate
        expr: sum by(pod, namespace, node) (rate(container_network_receive_bytes_total[2m]))
      - record: container:pod_transmit_bytes:sum_rate
        expr: sum by(pod, namespace, node) (rate(container_network_transmit_bytes_total[2m]))
      - record: namespace:instantaneous_receive_bytes:sum_irate
        expr: sort_desc(sum(irate(container_network_receive_bytes_total[2m])) by (namespace))
      - record: namespace:instantaneous_transmit_bytes:sum_irate
        expr: sort_desc(sum(irate(container_network_transmit_bytes_total[2m])) by (namespace))
      - record: namespace:byte_receive_rate:sum_rate
        expr: sort_desc(sum(rate(container_network_receive_bytes_total[2m])) by (namespace))
      - record: namespace:byte_transmit_rate:sum_rate
        expr: sort_desc(sum(rate(container_network_transmit_bytes_total[2m])) by (namespace))
      - record: namespace:packet_receive_rate:sum_rate
        expr: sort_desc(sum(rate(container_network_receive_packets_total[2m])) by (namespace))
      - record: namespace:packet_transmit_rate:sum_rate
        expr: sort_desc(sum(rate(container_network_transmit_packets_total[2m])) by (namespace))
      - record: namespace:cpu_usage_trend:sum_rate
        expr: sum(rate(container_cpu_usage_seconds_total{image!=""}[2m])) by (namespace)
      - record: namespace:memory_usage_trend:sum
        expr: sum(container_memory_usage_bytes{image!=""}) by (namespace)
kubeApiServer:
 enabled: false
kubeEtcd:
 enabled: false
kubelet:
  enabled: true
  serviceMonitor:
    cAdvisorMetricRelabelings:
      - sourceLabels: [__name__]
        action: drop
        regex: 'container_cpu_(cfs_throttled_seconds_total|load_average_10s|system_seconds_total|user_seconds_total)'
      - sourceLabels: [__name__]
        action: drop
        regex: 'container_fs_(io_current|io_time_seconds_total|io_time_weighted_seconds_total|reads_merged_total|sector_reads_total|sector_writes_total|writes_merged_total)'
      - sourceLabels: [__name__]
        action: drop
        regex: 'container_memory_(mapped_file|swap)'
      - sourceLabels: [__name__]
        action: drop
        regex: 'container_(file_descriptors|tasks_state|threads_max)'
      - sourceLabels: [__name__]
        action: drop
        regex: 'container_spec.*'
      - sourceLabels: [__name__]
        action: drop
        regex: 'storage_operation_duration_seconds_.*'
      - sourceLabels: [__name__]
        action: drop
        regex: 'kubelet_http_requests_duration_seconds_.*|container_blkio_device_usage_.*'
      - sourceLabels: [id, pod]
        action: drop
        regex: '.+;'
      - action: labeldrop
        regex: 'id|job|endpoint|metrics_path' 
    probesMetricRelabelings:
      - action: labeldrop
        regex: 'id|job|endpoint|metrics_path'
      - sourceLabels: [__name__]
        action: drop
        regex: 'prober_probe_duration_.*|kubelet_http_requests_duration_seconds_.*'
    cAdvisorRelabelings:
      - action: replace
        sourceLabels: [__metrics_path__]
        targetLabel: metrics_path
      - action: labeldrop
        regex: 'metrics_path'
      - sourceLabels: [__name__]
        action: drop
        regex: 'storage_operation_duration_seconds_.*|kubelet_http_requests_duration_seconds_.*|container_blkio_device_usage_total.*'
    probesRelabelings:
      - action: replace
        sourceLabels: [__metrics_path__]
        targetLabel: metrics_path
      - action: labeldrop
        regex: 'metrics_path'
      - sourceLabels: [__name__]
        action: drop
        regex: 'prober_probe_duration_.*|kubelet_http_requests_duration_seconds_.*'
    metricRelabelings:
      - action: labeldrop
        regex: 'id|endpoint|job|metrics_path'
      - sourceLabels: [__name__]
        action: drop
        regex: 'kubelet_runtime_operations_duration_.*|csi_operations_.*|storage_operation_duration_seconds_.*|volume_operation_total_seconds_*|kubernetes_feature_enabled|rest_client_.*|kubelet_http_requests_duration_seconds_.*'
    relabelings:
      - action: replace
        sourceLabels: [__metrics_path__]
        targetLabel: metrics_path
      - action: labeldrop
        regex: 'metrics_path'
      - sourceLabels: [__name__]
        action: drop
        regex: 'kubelet_runtime_operations_duration_.*|csi_operations_.*|storage_operation_duration_seconds_.*|volume_operation_total_seconds_*|kubernetes_feature_enabled|rest_client_.*|kubelet_http_requests_duration_seconds_.*'
    
  
kubeProxy:
  enabled: false

kubeStateMetrics:
  enabled: true
  resources:
    requests:
      memory: 50Mi
      cpu: 5m
    limits:
      memory: 1Gi
      cpu: 100m

kube-state-metrics:
  prometheus:
    monitor:
      enabled: true
      sampleLimit: 1000000
      targetLimit: 3
      labelLimit: 35
      metricRelabelings:
        - action: labeldrop
          regex: 'id|job|endpoint|metrics_path'
        - sourceLabels: [__name__]
          action: drop
          regex: 'kubernetes_feature_enabled|rest_client.*'
        - sourceLabels: [__name__]
          action: keep
          regex: '^kube_.*_info$|^kube_.*_labels$|kube_pod_status_phase|kube_pod_spec_volumes_persistentvolumeclaims_info|kube_persistentvolumeclaim_status_phase|kube_node_status_condition|kube_node_spec_unschedulable|kube_pod_status_qos_class|kube_pod_container_.*|kube_pod_status_reason|kube_node_.*'
  resources:
    requests:
      memory: 50Mi
      cpu: 5m
    limits:
      memory: 1Gi
      cpu: 100m


nodeExporter:
  resources:
    requests:
      memory: 10Mi
      cpu: 1m
    limits:
      memory: 40Mi
      cpu: 20m

prometheus-node-exporter:
  extraArgs:
    - --collector.disable-defaults
    - --collector.cpu
    - --collector.meminfo
    - --collector.diskstats
    - --collector.filesystem
    - --collector.stat
    - --collector.netdev
    - --collector.uname
    - --collector.nvme
    - --collector.time
    - --collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/.+)($|/)
    - --collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$

  prometheus:
    monitor:
      enabled: true

      sampleLimit: 15000
      targetLimit: 20
      labelLimit: 30

      metricRelabelings:
        - sourceLabels: [__name__]
          action: drop
          regex: 'node_(netstat_.*6|nf_conntrack_stat).*'
        - sourceLabels: [__name__]
          action: keep
          regex: 'node_(cpu|memory|boot|filesystem|network|disk|uname|nvme|time).*'
        - action: labeldrop
          regex: 'job|endpoint'
  resources:
    requests:
      memory: 10Mi
      cpu: 1m
    limits:
      memory: 40Mi
      cpu: 20m

prometheusOperator:
  admissionWebhooks:
    deployment:
      resources:
        limits:
          cpu: 200m
          memory: 200Mi
        requests:
          cpu: 5m
          memory: 50Mi
    patch:
      resources:
        requests:
          memory: 50Mi
          cpu: 5m
        limits:
          memory: 100Mi
          cpu: 100m
  resources:
    requests:
      memory: 50Mi
      cpu: 5m
    limits:
      memory: 300Mi
      cpu: 100m
  prometheusConfigReloader:
    resources:
      requests:
        cpu: 1m
        memory: 15Mi
      limits:
        cpu: 40m
        memory: 150Mi


prometheus:
  prometheusSpec:
    scrapeInterval: 15s
    retention: 10d
    retentionSize: 45GB
    resources:
      requests:
        memory: 300Mi
        cpu: 40m
      limits:
        memory: 4Gi
        cpu: 1
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: prometheus-sc
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 75Gi
    enforcedSampleLimit: 1500000
    enforcedTargetLimit: 50
    enforcedLabelLimit: 50

    
alertmanager:
  enabled: false

grafana:
    enabled: true
    defaultDashboardsEnabled: false
    persistence:
      enabled: true
      type: pvc
      storageClassName: prometheus-sc
      accessModes: ["ReadWriteOnce"]
      size: 15Gi
    sidecar:
      resources:
        requests:
          memory: 100Mi
          cpu: 1m
        limits:
          memory: 500Mi
          cpu: 40m
    additionalDataSources:
    - name: Loki
      type: loki
      url: http://loki-loki-distributed-query-frontend.monitoring:3100
    resources:
      requests:
        memory: 250Mi
        cpu: 10m
      limits:
        memory: 1.5Gi
        cpu: 200m
EOF
