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

cat << EOF > /root/scrtipts/json-files/ncs_dashboard.json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "target": {
          "limit": 100,
          "matchAny": false,
          "tags": [],
          "type": "dashboard"
        },
        "type": "dashboard"
      }
    ]
  },
  "description": "to monitor pod cpu, memory, I/O, RX/TX and cluster cpu, memory request/limit/real usage, RX/TX, Disk I/O ",
  "editable": true,
  "fiscalYearStartMonth": 0,
  "gnetId": 18283,
  "graphTooltip": 0,
  "id": 2,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "collapsed": false,
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 40,
      "panels": [],
      "title": "EKS Cluster Overview",
      "type": "row"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "decimals": 2,
          "mappings": [],
          "max": 1,
          "min": 0,
          "thresholds": {
            "mode": "percentage",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "orange",
                "value": 50
              },
              {
                "color": "red",
                "value": 70
              }
            ]
          },
          "unit": "percentunit"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 4,
        "x": 0,
        "y": 1
      },
      "id": 7,
      "options": {
        "minVizHeight": 75,
        "minVizWidth": 75,
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true,
        "sizing": "auto",
        "text": {}
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "cluster:cluster_cpu_usage:sum_ratio_rate",
          "instant": true,
          "interval": "$resolution",
          "legendFormat": "__auto",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "EKS Cluster CPU  Usage",
      "type": "gauge"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "decimals": 2,
          "mappings": [],
          "max": 1,
          "min": 0,
          "thresholds": {
            "mode": "percentage",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "orange",
                "value": 50
              },
              {
                "color": "red",
                "value": 70
              }
            ]
          },
          "unit": "percentunit"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 4,
        "x": 4,
        "y": 1
      },
      "id": 13,
      "options": {
        "minVizHeight": 75,
        "minVizWidth": 75,
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true,
        "sizing": "auto",
        "text": {}
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "cluster:cluster_memory_usage:sum_ratio",
          "instant": true,
          "interval": "$resolution",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "EKS Cluster RAM Usage",
      "type": "gauge"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "decimals": 2,
          "mappings": [],
          "max": 1,
          "min": 0,
          "thresholds": {
            "mode": "percentage",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "orange",
                "value": 50
              },
              {
                "color": "red",
                "value": 70
              }
            ]
          },
          "unit": "percentunit"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 4,
        "x": 8,
        "y": 1
      },
      "id": 107,
      "options": {
        "minVizHeight": 75,
        "minVizWidth": 75,
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true,
        "sizing": "auto",
        "text": {}
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "(sum(ncs_cluster_disk_use_bytes{tier=\"Cold Tier\"}) + sum(ncs_cluster_disk_use_bytes{tier=\"Hot Tier\"}) - sum (kubelet_volume_stats_used_bytes{persistentvolumeclaim=~\"pvc-state-disk-aos-sc.*\"} OR vector(0)))/ (sum (ncs_cluster_disk_size_bytes{tier=\"Cold Tier\"}) + sum(ncs_cluster_disk_size_bytes{tier=\"Hot Tier\"}) - sum (kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~\"pvc-state-disk-aos-sc.*\"} OR vector(0)))",
          "instant": true,
          "interval": "$resolution",
          "legendFormat": "__auto",
          "refId": "A"
        }
      ],
      "title": "EKS Cluster Disk Usage",
      "type": "gauge"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "custom": {
            "align": "auto",
            "cellOptions": {
              "type": "auto"
            },
            "inspect": false
          },
          "links": [
            {
              "targetBlank": true,
              "title": "Pod details",
              "url": "/d/k8s_views_pods/kubernetes-views-pods?${datasource:queryparam}&var-namespace=${__data.fields.namespace}&var-pod=${__data.fields.pod}&${resolution:queryparam}&${__url_time_range}"
            }
          ],
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 1
      },
      "id": 5,
      "options": {
        "cellHeight": "sm",
        "footer": {
          "countRows": false,
          "fields": "",
          "reducer": [
            "sum"
          ],
          "show": false
        },
        "showHeader": true,
        "sortBy": []
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": true,
          "expr": "kube_pod_info{pod_ip!=\"\"}",
          "format": "table",
          "interval": "",
          "legendFormat": "",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "List of pods on EKS cluster",
      "transformations": [
        {
          "id": "organize",
          "options": {
            "excludeByName": {
              "Time": true,
              "Value": true,
              "__name__": true,
              "container": true,
              "created_by_kind": false,
              "created_by_name": true,
              "endpoint": true,
              "env": true,
              "host_ip": true,
              "host_network": true,
              "instance": true,
              "job": true,
              "node": true,
              "project": true,
              "prometheus_replica": true,
              "service": true,
              "uid": true
            },
            "indexByName": {
              "Time": 6,
              "Value": 20,
              "__name__": 7,
              "container": 8,
              "created_by_kind": 2,
              "created_by_name": 9,
              "endpoint": 10,
              "env": 11,
              "host_ip": 5,
              "host_network": 12,
              "instance": 13,
              "job": 14,
              "namespace": 1,
              "node": 15,
              "pod": 0,
              "pod_ip": 3,
              "priority_class": 4,
              "project": 16,
              "prometheus_replica": 17,
              "service": 18,
              "uid": 19
            },
            "renameByName": {}
          }
        },
        {
          "id": "groupBy",
          "options": {
            "fields": {
              "created_by_kind": {
                "aggregations": [],
                "operation": "groupby"
              },
              "host_ip": {
                "aggregations": [],
                "operation": "groupby"
              },
              "namespace": {
                "aggregations": [
                  "last"
                ],
                "operation": "groupby"
              },
              "pod": {
                "aggregations": [],
                "operation": "groupby"
              },
              "pod_ip": {
                "aggregations": [],
                "operation": "groupby"
              },
              "priority_class": {
                "aggregations": [],
                "operation": "groupby"
              }
            }
          }
        }
      ],
      "type": "table"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "decimals": 3,
          "mappings": [],
          "noValue": "0",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "rgb(255, 255, 255)",
                "value": null
              }
            ]
          },
          "unit": "none"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 0,
        "y": 9
      },
      "id": 9,
      "options": {
        "colorMode": "none",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "text": {},
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum(rate(node_cpu_seconds_total{mode!~\"idle|iowait|steal\"}[$__rate_interval]))",
          "instant": true,
          "interval": "$resolution",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "CPU Used",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "noValue": "0",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "rgb(255, 255, 255)",
                "value": null
              }
            ]
          },
          "unit": "none"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 2,
        "y": 9
      },
      "id": 11,
      "options": {
        "colorMode": "none",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "text": {},
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum(machine_cpu_cores)",
          "instant": true,
          "interval": "$resolution",
          "legendFormat": "",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "CPU Total",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "noValue": "0",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "rgb(255, 255, 255)",
                "value": null
              }
            ]
          },
          "unit": "bytes"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 4,
        "y": 9
      },
      "id": 15,
      "options": {
        "colorMode": "none",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "text": {},
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)",
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "RAM Used",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "noValue": "0",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "rgb(255, 255, 255)",
                "value": null
              }
            ]
          },
          "unit": "bytes"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 6,
        "y": 9
      },
      "id": 17,
      "options": {
        "colorMode": "none",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "text": {},
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum(machine_memory_bytes)",
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "RAM Total",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "noValue": "0",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "rgb(255, 255, 255)",
                "value": null
              }
            ]
          },
          "unit": "bytes"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 8,
        "y": 9
      },
      "id": 105,
      "options": {
        "colorMode": "none",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "text": {},
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum(ncs_cluster_disk_use_bytes{tier=\"Cold Tier\"}) + sum(ncs_cluster_disk_use_bytes{tier=\"Hot Tier\"}) - sum (kubelet_volume_stats_used_bytes{persistentvolumeclaim=~\"pvc-state-disk-aos-sc.*\"} OR vector(0))",
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "title": "Disk Used",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "noValue": "0",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "rgb(255, 255, 255)",
                "value": null
              }
            ]
          },
          "unit": "bytes"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 2,
        "x": 10,
        "y": 9
      },
      "id": 106,
      "options": {
        "colorMode": "none",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "text": {},
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum (ncs_cluster_disk_size_bytes{tier=\"Cold Tier\"}) + sum(ncs_cluster_disk_size_bytes{tier=\"Hot Tier\"}) - sum (kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~\"pvc-state-disk-aos-sc.*\"} OR vector(0))",
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "Disk Total",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "noValue": "0",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "blue",
                "value": null
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 6,
        "x": 12,
        "y": 9
      },
      "id": 24,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "text": {},
        "textMode": "value",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": true,
          "expr": "sum(kube_pod_info)",
          "interval": "",
          "legendFormat": "",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Total Pods",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "noValue": "0",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "unit": "s"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 6,
        "x": 18,
        "y": 9
      },
      "id": 18,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "text": {},
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "max(node_time_seconds - node_boot_time_seconds)",
          "instant": true,
          "interval": "",
          "legendFormat": "__auto",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "uptime",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 6,
        "x": 0,
        "y": 12
      },
      "id": 161,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "/^eks_cluster_name$/",
          "values": false
        },
        "showPercentChange": false,
        "text": {
          "valueSize": 30
        },
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "eks_cluster_metadata_info",
          "format": "table",
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "EKS Cluster Name",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 6,
        "x": 6,
        "y": 12
      },
      "id": 153,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "/^name$/",
          "values": false
        },
        "showPercentChange": false,
        "text": {
          "valueSize": 30
        },
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "ncs_cluster_info",
          "format": "table",
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "NCS Cluster Name",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "custom": {
            "align": "auto",
            "cellOptions": {
              "type": "auto"
            },
            "inspect": false
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 6,
        "w": 12,
        "x": 12,
        "y": 12
      },
      "id": 162,
      "options": {
        "cellHeight": "sm",
        "footer": {
          "countRows": false,
          "fields": "",
          "reducer": [
            "sum"
          ],
          "show": false
        },
        "showHeader": true,
        "sortBy": []
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "eks_cluster_metadata_info",
          "format": "table",
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "EKS Cluster Details",
      "transformations": [
        {
          "id": "organize",
          "options": {
            "excludeByName": {
              "Time": true,
              "Value": true,
              "__name__": true,
              "container": true,
              "eks_nodegroup_role": true,
              "endpoint": true,
              "instance": true,
              "job": true,
              "namespace": true,
              "pod": true,
              "service": true
            },
            "includeByName": {},
            "indexByName": {
              "Time": 0,
              "Value": 14,
              "__name__": 1,
              "container": 3,
              "eks_cluster_id": 4,
              "eks_cluster_ip": 5,
              "eks_cluster_name": 2,
              "eks_nodegroup_name": 6,
              "eks_nodegroup_role": 7,
              "endpoint": 8,
              "instance": 9,
              "job": 10,
              "namespace": 11,
              "pod": 12,
              "service": 13
            },
            "renameByName": {
              "eks_cluster_id": "EKS Cluster ARN",
              "eks_cluster_ip": "EKS Cluster IP CIDR",
              "eks_cluster_name": "EKS Cluster Name",
              "eks_nodegroup_name": "EKS NodeGroup Name",
              "eks_nodegroup_role": "EKS NodeGroup Role",
              "endpoint": ""
            }
          }
        }
      ],
      "type": "table"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "max": 10,
          "min": 1,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "string"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 6,
        "x": 0,
        "y": 15
      },
      "id": 117,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "/^region$/",
          "values": false
        },
        "showPercentChange": false,
        "text": {
          "valueSize": 30
        },
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "label_replace(kube_node_info, \"region\", \"$7\", \"node\", \"ip(-)([0-9]*)-([0-9]*)-([0-9]*)-([0-9]*)(.)([a-z|-]*[0-9])(.)(.*)\")",
          "format": "table",
          "instant": true,
          "legendFormat": "{{region}}",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "Node Region",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 3,
        "w": 6,
        "x": 6,
        "y": 15
      },
      "id": 150,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "/^availability_zone$/",
          "values": false
        },
        "showPercentChange": false,
        "text": {
          "valueSize": 30
        },
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "ec2_metadata_info",
          "format": "table",
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "NCS Cluster Availability Zone",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "custom": {
            "align": "auto",
            "cellOptions": {
              "type": "auto"
            },
            "inspect": false
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Local Hostname"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 319
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "NCS Cluster Name"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 374
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "Subnet ID"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 317
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "VPC CIDR"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 190
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "VPC ID"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 246
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "Subnet CIDR"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 331
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "UUID"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 393
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 5,
        "w": 24,
        "x": 0,
        "y": 18
      },
      "id": 151,
      "options": {
        "cellHeight": "sm",
        "footer": {
          "countRows": false,
          "fields": "",
          "reducer": [
            "sum"
          ],
          "show": false
        },
        "frameIndex": 0,
        "showHeader": true,
        "sortBy": []
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "max (ec2_metadata_info) by (vpc_id, vpc_cidr, subnet_id, subnet_cidr, local_hostname)",
          "format": "table",
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "A"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "max (ncs_cluster_info) by (name, node_name)",
          "format": "table",
          "hide": false,
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "B"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "max (ncs_cluster_info) by (image, uuid)",
          "format": "table",
          "hide": false,
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "C"
        }
      ],
      "title": "NCS Cluster Details",
      "transformations": [
        {
          "id": "merge",
          "options": {}
        },
        {
          "id": "organize",
          "options": {
            "excludeByName": {
              "Time": true,
              "Value #A": true,
              "Value #B": true,
              "Value #C": true,
              "local_hostname": true,
              "node_name": true
            },
            "includeByName": {},
            "indexByName": {
              "Time": 0,
              "Value #A": 8,
              "Value #B": 10,
              "Value #C": 12,
              "image": 11,
              "local_hostname": 3,
              "name": 1,
              "node_name": 9,
              "subnet_cidr": 7,
              "subnet_id": 6,
              "uuid": 2,
              "vpc_cidr": 5,
              "vpc_id": 4
            },
            "renameByName": {
              "image": "NCS Cluster Image",
              "local_hostname": "Local Hostname",
              "name": "NCS Cluster Name",
              "subnet_cidr": "Subnet CIDR",
              "subnet_id": "Subnet ID",
              "uuid": "UUID",
              "vpc_cidr": "VPC CIDR",
              "vpc_id": "VPC ID"
            }
          }
        }
      ],
      "type": "table"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "axisSoftMax": 5,
            "axisSoftMin": 0,
            "fillOpacity": 80,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineWidth": 1,
            "scaleDistribution": {
              "type": "linear"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "decimals": 0,
          "mappings": [],
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 10,
        "w": 4,
        "x": 0,
        "y": 23
      },
      "id": 118,
      "options": {
        "barRadius": 0,
        "barWidth": 0.21,
        "fullHighlight": false,
        "groupWidth": 0.7,
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": false
        },
        "orientation": "vertical",
        "showValue": "auto",
        "stacking": "none",
        "tooltip": {
          "maxHeight": 600,
          "mode": "single",
          "sort": "none"
        },
        "xTickLabelRotation": 0,
        "xTickLabelSpacing": 0
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum by (region) (label_replace(kube_node_info, \"region\", \"$7\", \"node\", \"ip(-)([0-9]*)-([0-9]*)-([0-9]*)-([0-9]*)(.)([a-z|-]*[0-9])(.)(.*)\"))",
          "format": "table",
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "Nodes Per Region",
      "type": "barchart"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "custom": {
            "align": "center",
            "cellOptions": {
              "type": "auto"
            },
            "filterable": false,
            "inspect": false
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "short"
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Node"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 325
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 10,
        "w": 8,
        "x": 4,
        "y": 23
      },
      "id": 89,
      "options": {
        "cellHeight": "sm",
        "footer": {
          "countRows": false,
          "fields": "",
          "reducer": [
            "sum"
          ],
          "show": false
        },
        "showHeader": true,
        "sortBy": []
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum (kube_pod_info{node!=\"\"}) by (node)",
          "format": "table",
          "instant": true,
          "legendFormat": "{[node}}",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "Running pods per Instance",
      "transformations": [
        {
          "id": "organize",
          "options": {
            "excludeByName": {
              "Time": true
            },
            "includeByName": {},
            "indexByName": {},
            "renameByName": {
              "Value": "Number of Pods",
              "node": "Node"
            }
          }
        }
      ],
      "type": "table"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            }
          },
          "mappings": [],
          "unit": "none"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 10,
        "w": 12,
        "x": 12,
        "y": 23
      },
      "id": 88,
      "options": {
        "displayLabels": [
          "value"
        ],
        "legend": {
          "displayMode": "table",
          "placement": "right",
          "showLegend": true,
          "values": [
            "value"
          ]
        },
        "pieType": "donut",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "tooltip": {
          "maxHeight": 600,
          "mode": "multi",
          "sort": "desc"
        }
      },
      "pluginVersion": "9.1.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "expr": "count by(namespace) (kube_pod_info{})",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "No. of pods per Namespace",
      "type": "piechart"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 25,
            "gradientMode": "opacity",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 12,
        "w": 24,
        "x": 0,
        "y": 33
      },
      "id": 52,
      "options": {
        "legend": {
          "calcs": [
            "min",
            "max",
            "mean"
          ],
          "displayMode": "table",
          "placement": "right",
          "showLegend": true,
          "sortBy": "Max",
          "sortDesc": true
        },
        "tooltip": {
          "maxHeight": 600,
          "mode": "multi",
          "sort": "none"
        }
      },
      "pluginVersion": "8.3.3",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": true,
          "expr": "sum(kube_namespace_labels)",
          "interval": "",
          "legendFormat": "Namespaces",
          "range": true,
          "refId": "A"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_pod_container_status_running)",
          "interval": "",
          "legendFormat": "Running Containers",
          "range": true,
          "refId": "B"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_pod_status_phase{phase=\"Running\"})",
          "interval": "",
          "legendFormat": "Running Pods",
          "range": true,
          "refId": "O"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_service_info)",
          "interval": "",
          "legendFormat": "Services",
          "range": true,
          "refId": "C"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_endpoint_info)",
          "interval": "",
          "legendFormat": "Endpoints",
          "range": true,
          "refId": "D"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_ingress_info)",
          "interval": "",
          "legendFormat": "Ingresses",
          "range": true,
          "refId": "E"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_deployment_labels)",
          "interval": "",
          "legendFormat": "Deployments",
          "range": true,
          "refId": "F"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_statefulset_labels)",
          "interval": "",
          "legendFormat": "Statefulsets",
          "range": true,
          "refId": "G"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_daemonset_labels)",
          "interval": "",
          "legendFormat": "Daemonsets",
          "range": true,
          "refId": "H"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_persistentvolumeclaim_info)",
          "interval": "",
          "legendFormat": "Persistent Volume Claims",
          "range": true,
          "refId": "I"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_hpa_labels)",
          "interval": "",
          "legendFormat": "Horizontal Pod Autoscalers",
          "range": true,
          "refId": "J"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_configmap_info)",
          "interval": "",
          "legendFormat": "Configmaps",
          "range": true,
          "refId": "K"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_secret_info)",
          "interval": "",
          "legendFormat": "Secrets",
          "range": true,
          "refId": "L"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "expr": "sum(kube_networkpolicy_labels)",
          "interval": "",
          "legendFormat": "Network Policies",
          "range": true,
          "refId": "M"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": true,
          "expr": "count(count by (node) (kube_node_info))",
          "hide": false,
          "interval": "",
          "legendFormat": "Nodes",
          "range": true,
          "refId": "N"
        }
      ],
      "title": "Kubernetes Resource Count",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "continuous-GrYlRd",
            "seriesBy": "last"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "CPU %",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "scheme",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "smooth",
            "lineStyle": {
              "fill": "solid"
            },
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "decimals": 2,
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 0.5
              },
              {
                "color": "red",
                "value": 0.7
              }
            ]
          },
          "unit": "percentunit"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 10,
        "w": 12,
        "x": 0,
        "y": 45
      },
      "id": 72,
      "interval": "30s",
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "hidden",
          "placement": "right",
          "showLegend": false
        },
        "tooltip": {
          "maxHeight": 600,
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "8.3.3",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": true,
          "expr": "cluster:cpu_usage_trend:sum_rate",
          "interval": "$resolution",
          "legendFormat": "CPU usage in %",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "EKS Cluster CPU Utilization",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "continuous-GrYlRd"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "MEMORY",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 10,
            "gradientMode": "scheme",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "#EAB839",
                "value": 0.5
              },
              {
                "color": "red",
                "value": 0.7
              }
            ]
          },
          "unit": "percentunit"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 10,
        "w": 12,
        "x": 12,
        "y": 45
      },
      "id": 55,
      "options": {
        "legend": {
          "calcs": [
            "mean",
            "lastNotNull",
            "max",
            "min"
          ],
          "displayMode": "hidden",
          "placement": "right",
          "showLegend": false
        },
        "tooltip": {
          "maxHeight": 600,
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "8.3.3",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "editorMode": "code",
          "exemplar": true,
          "expr": "cluster:memory_usage_trend:sum",
          "interval": "$resolution",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "EKS Cluster Memory Utilization",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic",
            "seriesBy": "max"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "Bytes per second",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 25,
            "gradientMode": "opacity",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "smooth",
            "lineStyle": {
              "fill": "solid"
            },
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": true,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "binBps"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 10,
        "w": 12,
        "x": 0,
        "y": 55
      },
      "id": 20,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "right",
          "showLegend": true
        },
        "tooltip": {
          "maxHeight": 600,
          "mode": "multi",
          "sort": "desc"
        }
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "expr": "cluster:disk_read_trend:sum_rate{device=~\"nvme.*\"}",
          "hide": false,
          "legendFormat": "{{device}}-{{instance}}",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "EKS Cluster Disk Read Bandwidth (Device-Worker Node)",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic",
            "seriesBy": "max"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "Bytes per second",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 25,
            "gradientMode": "opacity",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "smooth",
            "lineStyle": {
              "fill": "solid"
            },
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": true,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "binBps"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 10,
        "w": 12,
        "x": 12,
        "y": 55
      },
      "id": 102,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "right",
          "showLegend": true
        },
        "tooltip": {
          "maxHeight": 600,
          "mode": "multi",
          "sort": "desc"
        }
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "expr": "cluster:disk_write_trend:sum_rate{device=~\"nvme.*\"}",
          "hide": false,
          "legendFormat": "{{device}}-{{instance}}",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "EKS Cluster Disk Write Bandwidth (Device-Worker Node)",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 8,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": true,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "s"
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "nvme2n1-10.100.1.210:9100"
            },
            "properties": [
              {
                "id": "color",
                "value": {
                  "fixedColor": "red",
                  "mode": "fixed"
                }
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 11,
        "w": 12,
        "x": 0,
        "y": 65
      },
      "id": 245,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "right",
          "showLegend": true
        },
        "tooltip": {
          "maxHeight": 600,
          "mode": "single",
          "sort": "none"
        }
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "expr": "rate(node_disk_read_time_seconds_total{device=~\"nvme.+\"}[1m]) / rate(node_disk_reads_completed_total{device=~\"nvme.+\"}[1m])",
          "instant": false,
          "legendFormat": "{{device}}-{{instance}}",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "EKS Cluster Disk Average Read Latency Per Minute (Device - Worker Node)",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 8,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "smooth",
            "lineWidth": 2,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "never",
            "spanNulls": true,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "s"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 11,
        "w": 12,
        "x": 12,
        "y": 65
      },
      "id": 246,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "right",
          "showLegend": true
        },
        "tooltip": {
          "maxHeight": 600,
          "mode": "single",
          "sort": "none"
        }
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "expr": "rate(node_disk_write_time_seconds_total{device=~\"nvme.+\"}[1m]) / rate(node_disk_writes_completed_total{device=~\"nvme.+\"}[1m])",
          "instant": false,
          "legendFormat": "{{device}}-{{instance}}",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "EKS Cluster Disk Average Write Latency Per Minute (Device - Worker Node)",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "custom": {
            "align": "auto",
            "cellOptions": {
              "type": "auto"
            },
            "filterable": false,
            "inspect": false
          },
          "mappings": [],
          "max": 100,
          "min": 0,
          "noValue": "--",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "light-green",
                "value": null
              }
            ]
          },
          "unit": "none"
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Used (%)"
            },
            "properties": [
              {
                "id": "custom.cellOptions",
                "value": {
                  "mode": "gradient",
                  "type": "gauge"
                }
              },
              {
                "id": "thresholds",
                "value": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "light-green",
                      "value": null
                    },
                    {
                      "color": "semi-dark-yellow",
                      "value": 70
                    },
                    {
                      "color": "dark-red",
                      "value": 80
                    }
                  ]
                }
              },
              {
                "id": "decimals",
                "value": 1
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "Status"
            },
            "properties": [
              {
                "id": "custom.cellOptions",
                "value": {
                  "mode": "gradient",
                  "type": "color-background"
                }
              },
              {
                "id": "mappings",
                "value": [
                  {
                    "options": {
                      "0": {
                        "text": "Bound"
                      },
                      "1": {
                        "text": "Pending"
                      },
                      "2": {
                        "text": "Lost"
                      }
                    },
                    "type": "value"
                  }
                ]
              },
              {
                "id": "thresholds",
                "value": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "light-green",
                      "value": null
                    },
                    {
                      "color": "light-green",
                      "value": 0
                    },
                    {
                      "color": "semi-dark-orange",
                      "value": 1
                    },
                    {
                      "color": "semi-dark-red",
                      "value": 2
                    }
                  ]
                }
              },
              {
                "id": "noValue",
                "value": "--"
              },
              {
                "id": "custom.align",
                "value": "center"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "Persistent Volume Claim"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 185
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 12,
        "w": 24,
        "x": 0,
        "y": 76
      },
      "id": 29,
      "interval": "",
      "options": {
        "cellHeight": "sm",
        "footer": {
          "countRows": false,
          "fields": "",
          "reducer": [
            "sum"
          ],
          "show": false
        },
        "frameIndex": 2,
        "showHeader": true,
        "sortBy": []
      },
      "pluginVersion": "11.0.0",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "expr": "sum by (persistentvolumeclaim,pod,volume) (kube_pod_spec_volumes_persistentvolumeclaims_info{persistentvolumeclaim!~\"pvc-state-disk-aos-sc-.+|ncs-disk.*\"})",
          "format": "table",
          "hide": false,
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "refId": "A"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "expr": "sum by (persistentvolumeclaim) (kubelet_volume_stats_capacity_bytes{persistentvolumeclaim!~\"pvc-state-disk-aos-sc-.+|ncs-disk.*\"}/1024/1024/1024)",
          "format": "table",
          "hide": false,
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "refId": "B"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "expr": "sum by (persistentvolumeclaim) (kubelet_volume_stats_used_bytes{persistentvolumeclaim!~\"pvc-state-disk-aos-sc-.+|ncs-disk.*\"}/1024/1024/1024)",
          "format": "table",
          "hide": false,
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "refId": "C"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "expr": "sum by (persistentvolumeclaim) (kubelet_volume_stats_available_bytes{persistentvolumeclaim!~\"pvc-state-disk-aos-sc-.+|ncs-disk.*\"}/1024/1024/1024)",
          "format": "table",
          "hide": false,
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "refId": "D"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "expr": "sum(kube_persistentvolumeclaim_status_phase{phase=~\"(Pending|Lost)\", persistentvolumeclaim!~\"pvc-state-disk-aos-sc-.+|ncs-disk.*\"}) by (persistentvolumeclaim) + sum(kube_persistentvolumeclaim_status_phase{phase=~\"(Lost)\", persistentvolumeclaim!~\"pvc-state-disk-aos-sc-.+|ncs-disk.*\"}) by (persistentvolumeclaim)",
          "format": "table",
          "hide": false,
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "refId": "E"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "editorMode": "code",
          "expr": "sum by (persistentvolumeclaim) (kubelet_volume_stats_used_bytes/kubelet_volume_stats_capacity_bytes{persistentvolumeclaim!~\"pvc-state-disk-aos-sc-.+|ncs-disk.*\"} * 100)",
          "format": "table",
          "hide": false,
          "instant": true,
          "interval": "",
          "legendFormat": "",
          "refId": "F"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum by (persistentvolumeclaim, volumename) (label_replace(eks_cluster_pod_pvc_info{pvc_name!~\"pvc-state-disk-aos-sc-.+|ncs-disk.*\"}, \"persistentvolumeclaim\", \"$1\", \"pvc_name\", \"(.*)\"))",
          "format": "table",
          "hide": true,
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "G"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "sum by (persistentvolumeclaim, volumename, csi_driver) (kube_persistentvolumeclaim_info{persistentvolumeclaim!~\"pvc-state-disk-aos-sc-.+|ncs-disk.*\"} * on (volumename) group_left(csi_driver) label_replace(kube_persistentvolume_info, \"volumename\", \"$1\", \"persistentvolume\", \"(.*)\"))",
          "format": "table",
          "hide": false,
          "instant": true,
          "legendFormat": "__auto",
          "range": false,
          "refId": "H"
        }
      ],
      "title": "EKS Cluster Application PVCs",
      "transformations": [
        {
          "id": "seriesToColumns",
          "options": {
            "byField": "persistentvolumeclaim",
            "mode": "outer"
          }
        },
        {
          "id": "organize",
          "options": {
            "excludeByName": {
              "Time": true,
              "Time 1": true,
              "Time 2": true,
              "Time 3": true,
              "Time 4": true,
              "Time 5": true,
              "Time 6": true,
              "Value #A": true,
              "Value #G": true,
              "Value #H": true,
              "volumename": true
            },
            "includeByName": {},
            "indexByName": {
              "Time 1": 1,
              "Time 2": 6,
              "Time 3": 8,
              "Time 4": 10,
              "Time 5": 12,
              "Time 6": 14,
              "Time 7": 16,
              "Value #A": 5,
              "Value #B": 7,
              "Value #C": 9,
              "Value #D": 11,
              "Value #E": 13,
              "Value #F": 15,
              "Value #H": 18,
              "csi_driver": 4,
              "persistentvolumeclaim": 0,
              "pod": 2,
              "volume": 3,
              "volumename": 17
            },
            "renameByName": {
              "Time 1": "",
              "Time 2": "",
              "Time 3": "",
              "Time 4": "",
              "Time 5": "",
              "Time 6": "",
              "Value #A": "",
              "Value #B": "Capacity (GiB)",
              "Value #C": "Used (GiB)",
              "Value #D": "Available (GiB)",
              "Value #E": "Status",
              "Value #F": "Used (%)",
              "csi_driver": "CSI Driver",
              "namespace": "Namespace",
              "persistentvolumeclaim": "Persistent Volume Claim",
              "pod": "Pod Name",
              "volume": "PhysicalVolume"
            }
          }
        },
        {
          "id": "sortBy",
          "options": {
            "fields": {},
            "sort": [
              {
                "desc": true,
                "field": "Used (%)"
              }
            ]
          }
        },
        {
          "id": "sortBy",
          "options": {
            "fields": {},
            "sort": [
              {
                "desc": false,
                "field": "Status"
              }
            ]
          }
        }
      ],
      "type": "table"
    },
    {
      "collapsed": true,
      "datasource": {
        "type": "prometheus",
        "uid": "P1809F7CD0C75ACF3"
      },
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 88
      },
      "id": 22,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 8,
            "x": 0,
            "y": 2
          },
          "id": 87,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "none",
            "graphMode": "none",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "mean"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum (kube_node_info{node != \"\"})",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            }
          ],
          "title": "Number Of Worker Nodes",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "#299c46"
                  },
                  {
                    "color": "rgba(237, 129, 40, 0.89)",
                    "value": 1
                  },
                  {
                    "color": "#d44a3a"
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 8,
            "x": 8,
            "y": 2
          },
          "id": 25,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "background",
            "graphMode": "none",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "text": {
              "valueSize": 0
            },
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum(kube_node_status_condition{condition=\"OutOfDisk\", node=~\"$node\", status=\"true\"}) OR on() vector(0)",
              "format": "time_series",
              "instant": true,
              "intervalFactor": 1,
              "range": false,
              "refId": "A"
            }
          ],
          "title": "Worker Nodes Out of Disk",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "#299c46"
                  },
                  {
                    "color": "rgba(237, 129, 40, 0.89)",
                    "value": 1
                  },
                  {
                    "color": "#d44a3a"
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 8,
            "x": 16,
            "y": 2
          },
          "id": 26,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "background",
            "graphMode": "none",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "builder",
              "exemplar": false,
              "expr": "sum(kube_node_spec_unschedulable{node=~\"$node\"})",
              "format": "time_series",
              "instant": true,
              "intervalFactor": 1,
              "range": false,
              "refId": "A"
            }
          ],
          "title": "Worker Nodes Unavailable",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "CPU %",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "decimals": 2,
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "percentunit"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 5
          },
          "id": 54,
          "options": {
            "legend": {
              "calcs": [
                "min",
                "max",
                "mean"
              ],
              "displayMode": "table",
              "placement": "right",
              "showLegend": true,
              "sortBy": "Max",
              "sortDesc": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "instance:node_cpu_usage:avg_sum_ratio{instance=~\"$instance\"}",
              "interval": "$resolution",
              "legendFormat": "{{instance}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "CPU Utilization Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "MEMORY",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 5
          },
          "id": 73,
          "options": {
            "legend": {
              "calcs": [
                "min",
                "max",
                "mean"
              ],
              "displayMode": "table",
              "placement": "right",
              "showLegend": true,
              "sortBy": "Max",
              "sortDesc": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "instance:node_memory_usage:sum{instance=~\"$instance\"}",
              "interval": "$resolution",
              "legendFormat": "{{instance}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Memory Utilization Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "BANDWIDTH",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "decimals": 0,
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "binBps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 13
          },
          "id": 90,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "multi",
              "sort": "desc"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "instance:node_network_receive_bytes:sum_rate{instance=~\"$instance\"}",
              "instant": false,
              "legendFormat": "{{instance}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total Network Receive Bytes Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "BANDWIDTH",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "decimals": 0,
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "binBps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 13
          },
          "id": 101,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "multi",
              "sort": "desc"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "instance:node_network_transmit_bytes:sum_rate{instance=~\"$instance\"}",
              "hide": false,
              "legendFormat": "{{instance}}",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "Total Network Transmit Bytes Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "auto"
                },
                "inspect": false
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  },
                  {
                    "color": "#EAB839",
                    "value": 90
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": [
              {
                "matcher": {
                  "id": "byName",
                  "options": "device"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 100
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Available"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 88
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Disk Size"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 88
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Used"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 88
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Used, %"
                },
                "properties": [
                  {
                    "id": "unit",
                    "value": "percentunit"
                  },
                  {
                    "id": "custom.cellOptions",
                    "value": {
                      "mode": "gradient",
                      "type": "gauge",
                      "valueDisplayMode": "text"
                    }
                  },
                  {
                    "id": "max",
                    "value": 1
                  },
                  {
                    "id": "min",
                    "value": 0
                  },
                  {
                    "id": "thresholds",
                    "value": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "#EAB839",
                          "value": 0.8
                        },
                        {
                          "color": "red",
                          "value": 0.9
                        }
                      ]
                    }
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "model"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 280
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "serial"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 200
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Device"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 181
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Device ID"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 235
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Model"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 301
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Tier"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 121
                  }
                ]
              }
            ]
          },
          "gridPos": {
            "h": 10,
            "w": 24,
            "x": 0,
            "y": 23
          },
          "id": 113,
          "maxPerRow": 2,
          "options": {
            "cellHeight": "sm",
            "footer": {
              "countRows": false,
              "fields": [],
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "frameIndex": 0,
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "repeat": "node",
          "repeatDirection": "v",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "ncs_cluster_nvme_disk_info{node_name=~\"$node\"}",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "D"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum by (device_name, node_name, mountpath) (ncs_cluster_disk_size_bytes{node_name=~\"$node\", mountpath=~\"/home/nutanix/data/stargate-storage/disks/.+\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "E"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum by (device_name, node_name, mountpath) (ncs_cluster_disk_available_bytes{node_name=~\"$node\", mountpath=~\"/home/nutanix/data/stargate-storage/disks/.+\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "F"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum by (device_name, node_name, mountpath) (ncs_cluster_disk_use_bytes{node_name=~\"$node\", mountpath=~\"/home/nutanix/data/stargate-storage/disks/.+\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "G"
            }
          ],
          "title": "Disk Storage For Worker Node $node",
          "transformations": [
            {
              "id": "joinByField",
              "options": {
                "byField": "device_name",
                "mode": "inner"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time 1": true,
                  "Time 2": true,
                  "Time 3": true,
                  "Time 4": true,
                  "Value #D": true,
                  "Value #G": true,
                  "__name__": true,
                  "container": true,
                  "endpoint": true,
                  "instance": true,
                  "job": true,
                  "mountpath 2": true,
                  "mountpath 3": true,
                  "namespace": true,
                  "node_name 1": true,
                  "node_name 2": true,
                  "node_name 3": true,
                  "node_name 4": true,
                  "pod": true,
                  "pod_name": true,
                  "service": true
                },
                "includeByName": {},
                "indexByName": {
                  "Time 1": 3,
                  "Time 2": 18,
                  "Time 3": 20,
                  "Time 4": 22,
                  "Value #D": 17,
                  "Value #E": 2,
                  "Value #F": 1,
                  "Value #G": 24,
                  "__name__": 4,
                  "container": 5,
                  "device_id": 6,
                  "device_model": 7,
                  "device_name": 0,
                  "endpoint": 8,
                  "instance": 9,
                  "job": 10,
                  "namespace": 11,
                  "node_name 1": 12,
                  "node_name 2": 19,
                  "node_name 3": 21,
                  "node_name 4": 23,
                  "pod": 13,
                  "pod_name": 14,
                  "service": 15,
                  "tier": 16
                },
                "renameByName": {
                  "Value #E": "Disk Size",
                  "Value #F": "Available",
                  "Value #G": "Used",
                  "device_id": "Device ID",
                  "device_model": "Model",
                  "device_name": "Device",
                  "mountpath 1": "MountPath",
                  "node_name 4": "",
                  "tier": "Tier"
                }
              }
            },
            {
              "id": "calculateField",
              "options": {
                "alias": "Used",
                "binary": {
                  "left": "Disk Size",
                  "operator": "-",
                  "right": "Available"
                },
                "mode": "binary",
                "reduce": {
                  "reducer": "sum"
                }
              }
            },
            {
              "id": "calculateField",
              "options": {
                "alias": "Used, %",
                "binary": {
                  "left": "Used",
                  "operator": "/",
                  "right": "Disk Size"
                },
                "mode": "binary",
                "reduce": {
                  "reducer": "sum"
                }
              }
            },
            {
              "id": "sortBy",
              "options": {
                "fields": {},
                "sort": [
                  {
                    "desc": true,
                    "field": "Tier"
                  }
                ]
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "Bps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 13,
            "w": 12,
            "x": 0,
            "y": 53
          },
          "id": 114,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "repeat": "instance",
          "repeatDirection": "v",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "sum by (device) (label_replace(instance:node_disk_read_rate:sum_rate{instance=~\"$instance\", device=~\"nvme.+\"}, \"device\", \"$1\", \"device\", \"(.*)n(.*)\")) * on (device) group_left(serial) node_nvme_info{instance=~\"$instance\"}",
              "instant": false,
              "legendFormat": "{{device}}-{{serial}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Disk Read Rate For Worker Node $instance",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "Bps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 13,
            "w": 12,
            "x": 12,
            "y": 53
          },
          "id": 115,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "repeat": "instance",
          "repeatDirection": "v",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "sum by (device) (label_replace(instance:node_disk_write_rate:sum_rate{instance=~\"$instance\", device=~\"nvme.+\"}, \"device\", \"$1\", \"device\", \"(.*)n(.*)\")) * on (device) group_left(serial) node_nvme_info{instance=~\"$instance\"}",
              "instant": false,
              "legendFormat": "{{device}}-{{serial}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Disk Write Rate For Worker Node $instance",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "s"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 12,
            "w": 12,
            "x": 0,
            "y": 92
          },
          "id": 257,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "repeat": "instance",
          "repeatDirection": "v",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "sum by (device) (label_replace(rate(node_disk_read_time_seconds_total{device=~\"nvme.+\", instance=~\"$instance\"}[1m]) / rate(node_disk_reads_completed_total{device=~\"nvme.+\", instance=~\"$instance\"}[1m]), \"device\", \"$1\", \"device\", \"(.*)n(.*)\"))  * on (device) group_left(serial) node_nvme_info{instance=~\"$instance\"}",
              "instant": false,
              "legendFormat": "{{device}}-{{serial}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average Read Latency Per Minute  For Worker Node $instance",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "s"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 12,
            "w": 12,
            "x": 12,
            "y": 92
          },
          "id": 270,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "repeat": "instance",
          "repeatDirection": "v",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "sum by (device) (label_replace(rate(node_disk_write_time_seconds_total{device=~\"nvme.+\", instance=~\"$instance\"}[1m]) / rate(node_disk_writes_completed_total{device=~\"nvme.+\", instance=~\"$instance\"}[1m]), \"device\", \"$1\", \"device\", \"(.*)n(.*)\"))  * on (device) group_left(serial) node_nvme_info{instance=~\"$instance\"}",
              "instant": false,
              "legendFormat": "{{device}}-{{serial}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average Write Latency Per Minute For Worker Node $instance",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 12,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 18,
            "x": 0,
            "y": 128
          },
          "id": 132,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "repeat": "instance",
          "repeatDirection": "v",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "(\n  node_memory_MemTotal_bytes{instance=~\"$instance\"}\n-\n  node_memory_MemFree_bytes{instance=~\"$instance\"}\n-\n  node_memory_Buffers_bytes{instance=~\"$instance\"}\n-\n  node_memory_Cached_bytes{instance=~\"$instance\"}\n)",
              "instant": false,
              "legendFormat": "memory used",
              "range": true,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "node_memory_Buffers_bytes{instance=~\"$instance\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "memory buffers",
              "range": true,
              "refId": "B"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "node_memory_Cached_bytes{instance=~\"$instance\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "memory cached",
              "range": true,
              "refId": "C"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "node_memory_MemFree_bytes{instance=~\"$instance\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "memory free",
              "range": true,
              "refId": "D"
            }
          ],
          "title": "Memory Usage For Worker Node $instance",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "decimals": 2,
              "mappings": [],
              "max": 100,
              "min": 0,
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "#EAB839",
                    "value": 80
                  },
                  {
                    "color": "red",
                    "value": 90
                  }
                ]
              },
              "unit": "percent"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 6,
            "x": 18,
            "y": 128
          },
          "id": 116,
          "maxPerRow": 4,
          "options": {
            "minVizHeight": 75,
            "minVizWidth": 75,
            "orientation": "auto",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showThresholdLabels": false,
            "showThresholdMarkers": true,
            "sizing": "auto"
          },
          "pluginVersion": "11.0.0",
          "repeat": "instance",
          "repeatDirection": "v",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "100 -\n(\n  avg(node_memory_MemAvailable_bytes{instance=~\"$instance\"}) /\n  avg(node_memory_MemTotal_bytes{instance=~\"$instance\"})\n* 100\n)",
              "instant": false,
              "legendFormat": "$instance",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Memory Utilisation for Worker Node $instance",
          "type": "gauge"
        }
      ],
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "refId": "A"
        }
      ],
      "title": "EKS Worker Nodes",
      "type": "row"
    },
    {
      "collapsed": true,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 89
      },
      "id": 328,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "#629e51",
                "mode": "fixed"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 6,
            "x": 0,
            "y": 3
          },
          "id": 332,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "none",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_status_phase{namespace=~\"ncs-system|ncs-cluster-operator-system|monitoring|ntnx-system\", phase=\"Running\", pod=~\"$ncs_pods\"})",
              "format": "time_series",
              "interval": "",
              "intervalFactor": 1,
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total NCS System Pods Running",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "#629e51",
                "mode": "fixed"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 6,
            "x": 6,
            "y": 3
          },
          "id": 329,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "none",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_status_phase{namespace=~\"ncs-system|ncs-cluster-operator-system|monitoring|ntnx-system\", phase=\"Pending\", pod=~\"$ncs_pods\"})",
              "format": "time_series",
              "interval": "",
              "intervalFactor": 1,
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total NCS System Pods Pending",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "#629e51",
                "mode": "fixed"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 6,
            "x": 12,
            "y": 3
          },
          "id": 330,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "none",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_status_phase{namespace=~\"ncs-system|ncs-cluster-operator-system|monitoring|ntnx-system\", phase=\"Failed\", pod=~\"$ncs_pods\"})",
              "format": "time_series",
              "interval": "",
              "intervalFactor": 1,
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total NCS System Pods Failed",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "#629e51",
                "mode": "fixed"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 6,
            "x": 18,
            "y": 3
          },
          "id": 331,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "none",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_status_phase{namespace=~\"ncs-system|ncs-cluster-operator-system|monitoring|ntnx-system\", phase=\"Unknown\", pod=~\"$ncs_pods\"})",
              "format": "time_series",
              "interval": "",
              "intervalFactor": 1,
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total NCS System Pods Unknown",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "mappings": [],
              "noValue": "0",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "#EAB839",
                    "value": 2
                  },
                  {
                    "color": "#E24D42",
                    "value": 5
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 6
          },
          "id": 333,
          "options": {
            "cellHeight": "sm",
            "footer": {
              "countRows": false,
              "enablePagination": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum (kube_pod_container_status_restarts_total{pod=~\"$ncs_pods\", namespace=~\"$namespace\"}) by (pod)",
              "format": "table",
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            }
          ],
          "title": "NCS System Pod Restart Count",
          "transformations": [
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "Value": "Restart Count",
                  "pod": "NCS System Pods"
                }
              }
            },
            {
              "id": "sortBy",
              "options": {
                "fields": {},
                "sort": [
                  {
                    "desc": true,
                    "field": "Restart Count"
                  }
                ]
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "red",
                "mode": "fixed"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "mappings": [],
              "noValue": "Pods are Active",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              }
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 6
          },
          "id": 334,
          "options": {
            "cellHeight": "sm",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum (kube_pod_status_reason{namespace=~\"$namespace\", pod=~\"$ncs_pods\"}) by (pod, reason)",
              "format": "table",
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            }
          ],
          "title": "Inactive Pod Status",
          "transformations": [
            {
              "id": "filterByValue",
              "options": {
                "filters": [
                  {
                    "config": {
                      "id": "equal",
                      "options": {
                        "value": 1
                      }
                    },
                    "fieldName": "Value"
                  }
                ],
                "match": "all",
                "type": "include"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true,
                  "Value": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "Value": "",
                  "pod": "NCS System Pod",
                  "reason": "Status Reason"
                }
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "fillOpacity": 80,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineWidth": 1,
                "scaleDistribution": {
                  "type": "linear"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "short"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 9,
            "w": 12,
            "x": 0,
            "y": 14
          },
          "id": 335,
          "options": {
            "barRadius": 0,
            "barWidth": 0.97,
            "fullHighlight": false,
            "groupWidth": 0.7,
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "orientation": "auto",
            "showValue": "auto",
            "stacking": "none",
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            },
            "xTickLabelRotation": 0,
            "xTickLabelSpacing": 0
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum (kube_pod_status_qos_class{pod=~\"$ncs_pods\", namespace=~\"$namespace\"}) by (qos_class)",
              "format": "table",
              "instant": true,
              "interval": "",
              "legendFormat": "{{ qos_class }} pods",
              "range": false,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_info)",
              "hide": true,
              "legendFormat": "Total pods",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "NCS System Pods QoS classes",
          "type": "barchart"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              }
            },
            "overrides": [
              {
                "matcher": {
                  "id": "byName",
                  "options": "Pod"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 532
                  }
                ]
              }
            ]
          },
          "gridPos": {
            "h": 9,
            "w": 12,
            "x": 12,
            "y": 14
          },
          "id": 336,
          "options": {
            "cellHeight": "sm",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum (kube_pod_status_qos_class{pod=~\"$ncs_pods\", namespace=~\"$namespace\"}) by (pod, qos_class)",
              "format": "table",
              "instant": true,
              "interval": "",
              "legendFormat": "{{ qos_class }} pods",
              "range": false,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_info)",
              "hide": true,
              "legendFormat": "Total pods",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "NCS System Pods QoS classes",
          "transformations": [
            {
              "id": "filterByValue",
              "options": {
                "filters": [
                  {
                    "config": {
                      "id": "equal",
                      "options": {
                        "value": 1
                      }
                    },
                    "fieldName": "Value"
                  }
                ],
                "match": "all",
                "type": "include"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true,
                  "Value": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "pod": "Pod",
                  "qos_class": "QOS Class"
                }
              }
            },
            {
              "id": "sortBy",
              "options": {
                "fields": {},
                "sort": [
                  {
                    "desc": true,
                    "field": "QOS Class"
                  }
                ]
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "decimals": 3,
              "mappings": [],
              "noValue": "-",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 7,
            "w": 12,
            "x": 0,
            "y": 23
          },
          "id": 337,
          "options": {
            "cellHeight": "md",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "max by(pod) (kube_pod_container_resource_requests{pod=~\"$ncs_pods\", resource=\"cpu\", unit=\"core\", node=~\"$node\", namespace=~\"$namespace\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "max by(pod) (kube_pod_container_resource_limits{pod=~\"$ncs_pods\", resource=\"cpu\", unit=\"core\", node=~\"$node\",  namespace=~\"$namespace\"}) ",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "B"
            }
          ],
          "title": "NCS System Pods CPU Requirements",
          "transformations": [
            {
              "id": "joinByField",
              "options": {
                "byField": "pod",
                "mode": "outer"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "Value #A": "CPU Core Request",
                  "Value #B": "CPU Core Limit",
                  "pod": "NCS Pods"
                }
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "decimals": 2,
              "mappings": [],
              "noValue": "-",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": [
              {
                "matcher": {
                  "id": "byName",
                  "options": "pod"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 361
                  }
                ]
              }
            ]
          },
          "gridPos": {
            "h": 7,
            "w": 12,
            "x": 12,
            "y": 23
          },
          "id": 338,
          "options": {
            "cellHeight": "md",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "max by(pod) (kube_pod_container_resource_requests{pod=~\"$ncs_pods\", resource=\"memory\", unit=\"byte\", node=~\"$node\",  namespace=~\"$namespace\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "max by(pod) (kube_pod_container_resource_limits{pod=~\"$ncs_pods\", resource=\"memory\", unit=\"byte\", node=~\"$node\",  namespace=~\"$namespace\"}) ",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "B"
            }
          ],
          "title": "NCS System Pods Memory Requirements",
          "transformations": [
            {
              "id": "joinByField",
              "options": {
                "byField": "pod",
                "mode": "outer"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "Value #A": "Memory Request",
                  "Value #B": "Memory Limit",
                  "pod": "NCS Pods"
                }
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "CPU Cores",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 30
          },
          "id": 339,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "table",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "container:pod_cpu_usage:sum_ratio_rate{node=~\"$node\",  pod=~\"$ncs_pods\",  namespace=~\"$namespace\"}",
              "interval": "$resolution",
              "legendFormat": "{{ pod }}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "NCS System Pods CPU usage",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 30
          },
          "id": 340,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "table",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "container:pod_memory_usage:sum_ratio{node=~\"$node\",  pod=~\"$ncs_pods\",  namespace=~\"$namespace\"}",
              "interval": "$resolution",
              "legendFormat": "{{ pod }}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "NCS System Pods Memory usage",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "decimals": 2,
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 40
          },
          "id": 341,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "container:pod_receive_bytes:sum_rate{node=~\"$node\",  pod=~\"$ncs_pods\",  namespace=~\"$namespace\"}",
              "hide": false,
              "legendFormat": "{{pod}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "NCS System Pods Receive Bytes",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "decimals": 2,
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 40
          },
          "id": 342,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "container:pod_transmit_bytes:sum_rate{node=~\"$node\",  pod=~\"$ncs_pods\",  namespace=~\"$namespace\"}",
              "hide": false,
              "legendFormat": "{{pod}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "NCS System Pods Transmit Bytes",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "description": "",
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "auto"
                },
                "inspect": false
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  },
                  {
                    "color": "#EAB839",
                    "value": 90
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": [
              {
                "matcher": {
                  "id": "byName",
                  "options": "device"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 100
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Available"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 88
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Disk Size"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 88
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Used"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 88
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Used, %"
                },
                "properties": [
                  {
                    "id": "unit",
                    "value": "percentunit"
                  },
                  {
                    "id": "custom.cellOptions",
                    "value": {
                      "mode": "gradient",
                      "type": "gauge",
                      "valueDisplayMode": "text"
                    }
                  },
                  {
                    "id": "max",
                    "value": 1
                  },
                  {
                    "id": "min",
                    "value": 0
                  },
                  {
                    "id": "thresholds",
                    "value": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green",
                          "value": null
                        },
                        {
                          "color": "#EAB839",
                          "value": 0.8
                        },
                        {
                          "color": "red",
                          "value": 0.9
                        }
                      ]
                    }
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Pod Name"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 187
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Mountpath"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 211
                  }
                ]
              }
            ]
          },
          "gridPos": {
            "h": 10,
            "w": 24,
            "x": 0,
            "y": 50
          },
          "id": 358,
          "options": {
            "cellHeight": "sm",
            "footer": {
              "countRows": false,
              "fields": [],
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "frameIndex": 0,
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum by (device_name, node_name, pod_name) (ncs_cluster_nvme_disk_info{pod_name=~\"$aos_pods\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "D"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum by (device_name, node_name, mountpath, tier, pod_name) (ncs_cluster_disk_size_bytes{mountpath=~\"/home/nutanix/data/stargate-storage/disks/.+\", pod_name=~\"$ncs_pods\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "E"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum by (device_name, node_name, mountpath, tier, pod_name) (ncs_cluster_disk_available_bytes{mountpath=~\"/home/nutanix/data/stargate-storage/disks/.+\", pod_name=~\"$ncs_pods\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "F"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum by (device_name, node_name, mountpath, tier, pod_name) (ncs_cluster_disk_use_bytes{mountpath=~\"/home/nutanix/data/stargate-storage/disks/.+\", pod_name=~\"$ncs_pods\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "G"
            }
          ],
          "title": "AOS Data Disks",
          "transformations": [
            {
              "id": "joinByField",
              "options": {
                "byField": "mountpath",
                "mode": "inner"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time 1": true,
                  "Time 2": true,
                  "Time 3": true,
                  "Time 4": true,
                  "Value #D": true,
                  "Value #G": true,
                  "__name__": true,
                  "container": true,
                  "device_name 1": false,
                  "device_name 2": true,
                  "device_name 3": true,
                  "endpoint": true,
                  "instance": true,
                  "job": true,
                  "mountpath 2": true,
                  "mountpath 3": true,
                  "namespace": true,
                  "node_name 1": false,
                  "node_name 2": true,
                  "node_name 3": true,
                  "node_name 4": true,
                  "pod": true,
                  "pod_name": false,
                  "pod_name 1": false,
                  "pod_name 2": true,
                  "pod_name 3": true,
                  "service": true,
                  "tier 2": true,
                  "tier 3": true
                },
                "includeByName": {},
                "indexByName": {
                  "Time 1": 3,
                  "Time 2": 5,
                  "Time 3": 7,
                  "Value #E": 1,
                  "Value #F": 0,
                  "Value #G": 9,
                  "device_name 1": 11,
                  "device_name 2": 13,
                  "device_name 3": 16,
                  "mountpath": 10,
                  "node_name 1": 4,
                  "node_name 2": 6,
                  "node_name 3": 8,
                  "pod_name 1": 2,
                  "pod_name 2": 14,
                  "pod_name 3": 17,
                  "tier 1": 12,
                  "tier 2": 15,
                  "tier 3": 18
                },
                "renameByName": {
                  "Value #E": "Disk Size",
                  "Value #F": "Available",
                  "Value #G": "Used",
                  "device_id": "Device ID",
                  "device_model": "Model",
                  "device_name": "Device",
                  "device_name 1": "Device",
                  "mountpath": "Mountpath",
                  "mountpath 1": "MountPath",
                  "node_name 1": "Worker Node Name",
                  "node_name 4": "",
                  "pod_name 1": "Pod Name",
                  "tier": "Tier",
                  "tier 1": "Tier"
                }
              }
            },
            {
              "id": "calculateField",
              "options": {
                "alias": "Used",
                "binary": {
                  "left": "Disk Size",
                  "operator": "-",
                  "right": "Available"
                },
                "mode": "binary",
                "reduce": {
                  "reducer": "sum"
                }
              }
            },
            {
              "id": "calculateField",
              "options": {
                "alias": "Used, %",
                "binary": {
                  "left": "Used",
                  "operator": "/",
                  "right": "Disk Size"
                },
                "mode": "binary",
                "reduce": {
                  "reducer": "sum"
                }
              }
            },
            {
              "id": "sortBy",
              "options": {
                "fields": {},
                "sort": [
                  {
                    "desc": true,
                    "field": "Node Name"
                  }
                ]
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "auto"
                },
                "filterable": false,
                "inspect": false
              },
              "mappings": [],
              "max": 100,
              "min": 0,
              "noValue": "--",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "light-green",
                    "value": null
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": [
              {
                "matcher": {
                  "id": "byName",
                  "options": "Used (%)"
                },
                "properties": [
                  {
                    "id": "custom.cellOptions",
                    "value": {
                      "mode": "gradient",
                      "type": "gauge"
                    }
                  },
                  {
                    "id": "thresholds",
                    "value": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "light-green",
                          "value": null
                        },
                        {
                          "color": "semi-dark-yellow",
                          "value": 70
                        },
                        {
                          "color": "dark-red",
                          "value": 80
                        }
                      ]
                    }
                  },
                  {
                    "id": "decimals",
                    "value": 1
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Status"
                },
                "properties": [
                  {
                    "id": "custom.cellOptions",
                    "value": {
                      "mode": "gradient",
                      "type": "color-background"
                    }
                  },
                  {
                    "id": "mappings",
                    "value": [
                      {
                        "options": {
                          "0": {
                            "text": "Bound"
                          },
                          "1": {
                            "text": "Pending"
                          },
                          "2": {
                            "text": "Lost"
                          }
                        },
                        "type": "value"
                      }
                    ]
                  },
                  {
                    "id": "thresholds",
                    "value": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "light-green",
                          "value": null
                        },
                        {
                          "color": "light-green",
                          "value": 0
                        },
                        {
                          "color": "semi-dark-orange",
                          "value": 1
                        },
                        {
                          "color": "semi-dark-red",
                          "value": 2
                        }
                      ]
                    }
                  },
                  {
                    "id": "noValue",
                    "value": "--"
                  },
                  {
                    "id": "custom.align",
                    "value": "center"
                  }
                ]
              },
              {
                "matcher": {
                  "id": "byName",
                  "options": "Persistent Volume Claim"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 342
                  }
                ]
              }
            ]
          },
          "gridPos": {
            "h": 10,
            "w": 24,
            "x": 0,
            "y": 60
          },
          "id": 357,
          "interval": "",
          "options": {
            "cellHeight": "sm",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "frameIndex": 2,
            "showHeader": true,
            "sortBy": [
              {
                "desc": true,
                "displayName": "Used (%)"
              }
            ]
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": " sum by (persistentvolumeclaim,pod,volume) (kube_pod_spec_volumes_persistentvolumeclaims_info{persistentvolumeclaim=~\"pvc-state-disk-aos-sc-.+\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "interval": "",
              "legendFormat": "",
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum by (persistentvolumeclaim) (kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~\"pvc-state-disk-aos-sc-.+\"}/1024/1024/1024)",
              "format": "table",
              "hide": false,
              "instant": true,
              "interval": "",
              "legendFormat": "",
              "refId": "B"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum by (persistentvolumeclaim) (kubelet_volume_stats_used_bytes{persistentvolumeclaim=~\"pvc-state-disk-aos-sc-.+\"}/1024/1024/1024)",
              "format": "table",
              "hide": false,
              "instant": true,
              "interval": "",
              "legendFormat": "",
              "refId": "C"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum by (persistentvolumeclaim) (kubelet_volume_stats_available_bytes{persistentvolumeclaim=~\"pvc-state-disk-aos-sc-.+\"}/1024/1024/1024)",
              "format": "table",
              "hide": false,
              "instant": true,
              "interval": "",
              "legendFormat": "",
              "refId": "D"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum(kube_persistentvolumeclaim_status_phase{phase=~\"(Pending|Lost)\", persistentvolumeclaim=~\"pvc-state-disk-aos-sc-.+\"}) by (persistentvolumeclaim) + sum(kube_persistentvolumeclaim_status_phase{phase=~\"(Lost)\", persistentvolumeclaim=~\"pvc-state-disk-aos-sc-.+\"}) by (persistentvolumeclaim)",
              "format": "table",
              "hide": false,
              "instant": true,
              "interval": "",
              "legendFormat": "",
              "refId": "E"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum by (persistentvolumeclaim) (kubelet_volume_stats_used_bytes/kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~\"pvc-state-disk-aos-sc-.+\"} * 100)",
              "format": "table",
              "hide": false,
              "instant": true,
              "interval": "",
              "legendFormat": "",
              "refId": "F"
            }
          ],
          "title": "AOS Boot DIsks",
          "transformations": [
            {
              "id": "seriesToColumns",
              "options": {
                "byField": "persistentvolumeclaim",
                "mode": "outer"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true,
                  "Time 1": true,
                  "Time 2": true,
                  "Time 3": true,
                  "Time 4": true,
                  "Time 5": true,
                  "Time 6": true,
                  "Value #A": true
                },
                "indexByName": {},
                "renameByName": {
                  "Time 1": "",
                  "Time 2": "",
                  "Time 3": "",
                  "Time 4": "",
                  "Time 5": "",
                  "Time 6": "",
                  "Value #A": "",
                  "Value #B": "Capacity (GiB)",
                  "Value #C": "Used (GiB)",
                  "Value #D": "Available (GiB)",
                  "Value #E": "Status",
                  "Value #F": "Used (%)",
                  "namespace": "Namespace",
                  "persistentvolumeclaim": "Persistent Volume Claim",
                  "pod": "Pod Name",
                  "volume": "PhysicalVolume"
                }
              }
            }
          ],
          "type": "table"
        }
      ],
      "title": "NCS System Pods",
      "type": "row"
    },
    {
      "collapsed": true,
      "datasource": {
        "type": "prometheus",
        "uid": "P1809F7CD0C75ACF3"
      },
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 90
      },
      "id": 28,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "#629e51",
                "mode": "fixed"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 6,
            "x": 0,
            "y": 4
          },
          "id": 297,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "none",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_status_phase{phase=\"Running\", namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"})",
              "format": "time_series",
              "interval": "",
              "intervalFactor": 1,
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total Pods Running",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "#629e51",
                "mode": "fixed"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 6,
            "x": 6,
            "y": 4
          },
          "id": 30,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "none",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_status_phase{phase=\"Pending\", namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"})",
              "format": "time_series",
              "interval": "",
              "intervalFactor": 1,
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total Pods Pending",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "#629e51",
                "mode": "fixed"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 6,
            "x": 12,
            "y": 4
          },
          "id": 296,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "none",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_status_phase{phase=\"Failed\", namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"})",
              "format": "time_series",
              "hide": false,
              "interval": "",
              "intervalFactor": 1,
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total Pods Failed",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "#629e51",
                "mode": "fixed"
              },
              "mappings": [
                {
                  "options": {
                    "match": "null",
                    "result": {
                      "text": "N/A"
                    }
                  },
                  "type": "special"
                }
              ],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 6,
            "x": 18,
            "y": 4
          },
          "id": 295,
          "maxDataPoints": 100,
          "options": {
            "colorMode": "none",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "horizontal",
            "percentChangeColorMode": "standard",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "showPercentChange": false,
            "textMode": "auto",
            "wideLayout": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_status_phase{phase=\"Unknown\", namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"})",
              "format": "time_series",
              "interval": "",
              "intervalFactor": 1,
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total Pods Unknown",
          "type": "stat"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "mappings": [],
              "noValue": "0",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "#EAB839",
                    "value": 2
                  },
                  {
                    "color": "#E24D42",
                    "value": 5
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": [
              {
                "matcher": {
                  "id": "byName",
                  "options": "AOS Pods"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 874
                  }
                ]
              }
            ]
          },
          "gridPos": {
            "h": 7,
            "w": 12,
            "x": 0,
            "y": 7
          },
          "id": 309,
          "options": {
            "cellHeight": "md",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum (kube_pod_container_status_restarts_total{pod=~\"$application_pods\", namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}) by (pod)",
              "format": "table",
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            }
          ],
          "title": "Total Pod Restart Count",
          "transformations": [
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "Value": "Restart Count",
                  "pod": "Pods"
                }
              }
            },
            {
              "id": "sortBy",
              "options": {
                "fields": {},
                "sort": [
                  {
                    "desc": true,
                    "field": "Restart Count"
                  }
                ]
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "fixedColor": "red",
                "mode": "fixed"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "mappings": [],
              "noValue": "Pods are Active",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              }
            },
            "overrides": []
          },
          "gridPos": {
            "h": 7,
            "w": 12,
            "x": 12,
            "y": 7
          },
          "id": 310,
          "options": {
            "cellHeight": "sm",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum (kube_pod_status_reason{pod=~\"$application_pods\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}) by (pod, reason)",
              "format": "table",
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            }
          ],
          "title": "Total Pod Inactive Status",
          "transformations": [
            {
              "id": "filterByValue",
              "options": {
                "filters": [
                  {
                    "config": {
                      "id": "equal",
                      "options": {
                        "value": 1
                      }
                    },
                    "fieldName": "Value"
                  }
                ],
                "match": "all",
                "type": "include"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true,
                  "Value": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "Value": "",
                  "pod": "Pods",
                  "reason": "Status Reason"
                }
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "fillOpacity": 80,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineWidth": 1,
                "scaleDistribution": {
                  "type": "linear"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "short"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 9,
            "w": 12,
            "x": 0,
            "y": 14
          },
          "id": 84,
          "options": {
            "barRadius": 0,
            "barWidth": 0.97,
            "fullHighlight": false,
            "groupWidth": 0.7,
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "orientation": "auto",
            "showValue": "auto",
            "stacking": "none",
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            },
            "xTickLabelRotation": 0,
            "xTickLabelSpacing": 0
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum (kube_pod_status_qos_class{pod=~\"$application_pods\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}) by (qos_class)",
              "format": "table",
              "instant": true,
              "interval": "",
              "legendFormat": "{{ qos_class }} pods",
              "range": false,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_info)",
              "hide": true,
              "legendFormat": "Total pods",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "Kubernetes Pods QoS classes",
          "type": "barchart"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              }
            },
            "overrides": [
              {
                "matcher": {
                  "id": "byName",
                  "options": "Pod"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 545
                  }
                ]
              }
            ]
          },
          "gridPos": {
            "h": 9,
            "w": 12,
            "x": 12,
            "y": 14
          },
          "id": 311,
          "options": {
            "cellHeight": "sm",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "sum (kube_pod_status_qos_class{pod=~\"$application_pods\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}) by (pod, qos_class)",
              "format": "table",
              "instant": true,
              "interval": "",
              "legendFormat": "{{ qos_class }} pods",
              "range": false,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "expr": "sum(kube_pod_info)",
              "hide": true,
              "legendFormat": "Total pods",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "Kubernetes Pods QoS classes",
          "transformations": [
            {
              "id": "filterByValue",
              "options": {
                "filters": [
                  {
                    "config": {
                      "id": "equal",
                      "options": {
                        "value": 1
                      }
                    },
                    "fieldName": "Value"
                  }
                ],
                "match": "all",
                "type": "include"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true,
                  "Value": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "pod": "Pod",
                  "qos_class": "QOS Class"
                }
              }
            },
            {
              "id": "sortBy",
              "options": {
                "fields": {},
                "sort": [
                  {
                    "desc": true,
                    "field": "QOS Class"
                  }
                ]
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "decimals": 3,
              "mappings": [],
              "noValue": "-",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": [
              {
                "matcher": {
                  "id": "byName",
                  "options": "pod"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 361
                  }
                ]
              }
            ]
          },
          "gridPos": {
            "h": 7,
            "w": 12,
            "x": 0,
            "y": 23
          },
          "id": 312,
          "options": {
            "cellHeight": "md",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "max by(pod) (kube_pod_container_resource_requests{pod=~\"$application_pods\", resource=\"cpu\", unit=\"core\", node=~\"$node\", namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "max by(pod) (kube_pod_container_resource_limits{pod=~\"$application_pods\", resource=\"cpu\", unit=\"core\", node=~\"$node\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}) ",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "B"
            }
          ],
          "title": "Pod CPU Requirements",
          "transformations": [
            {
              "id": "joinByField",
              "options": {
                "byField": "pod",
                "mode": "outer"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "Value #A": "CPU Core Request",
                  "Value #B": "CPU Core Limit",
                  "pod": "Pods"
                }
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "custom": {
                "align": "auto",
                "cellOptions": {
                  "type": "color-text"
                },
                "inspect": false
              },
              "decimals": 2,
              "mappings": [],
              "noValue": "-",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": [
              {
                "matcher": {
                  "id": "byName",
                  "options": "pod"
                },
                "properties": [
                  {
                    "id": "custom.width",
                    "value": 361
                  }
                ]
              }
            ]
          },
          "gridPos": {
            "h": 7,
            "w": 12,
            "x": 12,
            "y": 23
          },
          "id": 313,
          "options": {
            "cellHeight": "md",
            "footer": {
              "countRows": false,
              "fields": "",
              "reducer": [
                "sum"
              ],
              "show": false
            },
            "showHeader": true,
            "sortBy": []
          },
          "pluginVersion": "11.0.0",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "max by(pod) (kube_pod_container_resource_requests{pod=~\"$application_pods\", resource=\"memory\", unit=\"byte\", node=~\"$node\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"})",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "max by(pod) (kube_pod_container_resource_limits{pod=~\"$application_pods\", resource=\"memory\", unit=\"byte\", node=~\"$node\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}) ",
              "format": "table",
              "hide": false,
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "B"
            }
          ],
          "title": "Pod Memory Requirements",
          "transformations": [
            {
              "id": "joinByField",
              "options": {
                "byField": "pod",
                "mode": "outer"
              }
            },
            {
              "id": "organize",
              "options": {
                "excludeByName": {
                  "Time": true
                },
                "includeByName": {},
                "indexByName": {},
                "renameByName": {
                  "Value #A": "Memory Request",
                  "Value #B": "Memory Limit",
                  "pod": "Pods"
                }
              }
            }
          ],
          "type": "table"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "CPU Cores",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 30
          },
          "id": 92,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "table",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "container:pod_cpu_usage:sum_ratio_rate{node=~\"$node\",  pod=~\"$application_pods\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}",
              "interval": "$resolution",
              "legendFormat": "{{ pod }}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "CPU usage Per Pod",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 30
          },
          "id": 95,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "table",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "container:pod_memory_usage:sum_ratio{node=~\"$node\",  pod=~\"$application_pods\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}",
              "interval": "$resolution",
              "legendFormat": "{{ pod }}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Memory usage Per Pod",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "decimals": 2,
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 40
          },
          "id": 91,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "container:pod_receive_bytes:sum_rate{node=~\"$node\",  pod=~\"$application_pods\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}",
              "hide": false,
              "legendFormat": "{{pod}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Network Receive Bytes Per Pod",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "decimals": 2,
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 40
          },
          "id": 100,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "P1809F7CD0C75ACF3"
              },
              "editorMode": "code",
              "expr": "container:pod_transmit_bytes:sum_rate{node=~\"$node\",  pod=~\"$application_pods\",  namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"}",
              "hide": false,
              "legendFormat": "{{pod}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Network Transmit Bytes Per Pod",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "iops"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 50
          },
          "id": 231,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_num_write_iops{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\", node_name=~\"$node\"}) by (pod_name)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_name}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Write IOPS Per Pod",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "iops"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 50
          },
          "id": 232,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_num_read_iops{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\", node_name=~\"$node\"}) by (pod_name)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_name}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Read IOPS Per Pod",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "KBs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 60
          },
          "id": 271,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_write_io_bandwidth_k_bps{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\",node_name=~\"$node\"}) by (pod_name)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_name}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Write Bandwidth Per Pod",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "KBs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 60
          },
          "id": 272,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_read_io_bandwidth_k_bps{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\", node_name=~\"$node\"}) by (pod_name)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_name}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Read Bandwidth Per Pod",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  }
                ]
              },
              "unit": "µs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 70
          },
          "id": 273,
          "interval": "15",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_avg_write_io_latency_usecs{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\", node_name=~\"$node\"}) by (pod_name)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_name}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Write Latency Per Pod",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  }
                ]
              },
              "unit": "µs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 70
          },
          "id": 274,
          "interval": "15",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_avg_read_io_latency_usecs{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace!~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\", node_name=~\"$node\"}) by (pod_name)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_name}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Read Latency Per Pod",
          "type": "timeseries"
        }
      ],
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P1809F7CD0C75ACF3"
          },
          "refId": "A"
        }
      ],
      "title": "Application Pods",
      "type": "row"
    },
    {
      "collapsed": true,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 91
      },
      "id": 86,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "CPU CORES",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineStyle": {
                  "fill": "solid"
                },
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "decimals": 2,
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 5
          },
          "id": 46,
          "options": {
            "legend": {
              "calcs": [
                "min",
                "max",
                "mean"
              ],
              "displayMode": "table",
              "placement": "right",
              "showLegend": true,
              "sortBy": "Max",
              "sortDesc": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "namespace:cpu_usage_trend:sum_rate{namespace=~\"$namespace\"}",
              "interval": "$resolution",
              "legendFormat": "{{namespace}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "CPU Utilization Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 5
          },
          "id": 50,
          "options": {
            "legend": {
              "calcs": [
                "min",
                "max",
                "mean"
              ],
              "displayMode": "table",
              "placement": "right",
              "showLegend": true,
              "sortBy": "Max",
              "sortDesc": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "namespace:memory_usage_trend:sum{namespace=~\"$namespace\"}",
              "interval": "$resolution",
              "legendFormat": "{{ namespace }}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Memory Utilization Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "Rate",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 7,
                "gradientMode": "hue",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "Bps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 14,
            "w": 12,
            "x": 0,
            "y": 13
          },
          "id": 137,
          "options": {
            "legend": {
              "calcs": [
                "min",
                "max",
                "mean",
                "lastNotNull"
              ],
              "displayMode": "table",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "namespace:byte_receive_rate:sum_rate{namespace=~\"$namespace\"}",
              "instant": false,
              "legendFormat": "{{namespace}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Receive Bandwidth Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "Rate",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "hue",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "Bps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 14,
            "w": 12,
            "x": 12,
            "y": 13
          },
          "id": 138,
          "options": {
            "legend": {
              "calcs": [
                "min",
                "max",
                "mean",
                "lastNotNull"
              ],
              "displayMode": "table",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "namespace:byte_transmit_rate:sum_rate{namespace=~\"$namespace\"}",
              "instant": false,
              "legendFormat": "{{namespace}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Transmit Bandwidth Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "Rate",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "auto",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "pps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 16,
            "w": 12,
            "x": 0,
            "y": 27
          },
          "id": 139,
          "options": {
            "legend": {
              "calcs": [
                "min",
                "max",
                "mean",
                "lastNotNull"
              ],
              "displayMode": "table",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "namespace:packet_receive_rate:sum_rate{namespace=~\"$namespace\"}",
              "instant": false,
              "legendFormat": "{{namespace}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Packet Receive Rate Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "Rate",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "auto",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "pps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 16,
            "w": 12,
            "x": 12,
            "y": 27
          },
          "id": 140,
          "options": {
            "legend": {
              "calcs": [
                "min",
                "max",
                "mean",
                "lastNotNull"
              ],
              "displayMode": "table",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "namespace:packet_transmit_rate:sum_rate{namespace=~\"$namespace\"}",
              "instant": false,
              "legendFormat": "{{namespace}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Packet Transmit Rate Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "continuous-YlBl"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "Rate",
                "axisPlacement": "auto",
                "fillOpacity": 80,
                "gradientMode": "hue",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineWidth": 1,
                "scaleDistribution": {
                  "type": "linear"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "min": 0,
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "Bps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 11,
            "w": 12,
            "x": 0,
            "y": 43
          },
          "id": 135,
          "options": {
            "barRadius": 0,
            "barWidth": 0.97,
            "colorByField": "Value",
            "fullHighlight": false,
            "groupWidth": 0.7,
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": false
            },
            "orientation": "auto",
            "showValue": "auto",
            "stacking": "none",
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            },
            "xField": "namespace",
            "xTickLabelRotation": 0,
            "xTickLabelSpacing": 0
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "namespace:instantaneous_receive_bytes:sum_irate{namespace=~\"$namespace\"}",
              "format": "table",
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            }
          ],
          "title": "Instantaneous Rate of Bytes Received Per Namespace",
          "type": "barchart"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "continuous-YlBl"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "Rate",
                "axisPlacement": "auto",
                "fillOpacity": 80,
                "gradientMode": "hue",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineWidth": 1,
                "scaleDistribution": {
                  "type": "linear"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "min": 0,
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "Bps"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 11,
            "w": 12,
            "x": 12,
            "y": 43
          },
          "id": 136,
          "options": {
            "barRadius": 0,
            "barWidth": 0.97,
            "colorByField": "Value",
            "fullHighlight": false,
            "groupWidth": 0.7,
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": false
            },
            "orientation": "auto",
            "showValue": "auto",
            "stacking": "none",
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            },
            "xField": "namespace",
            "xTickLabelRotation": 0,
            "xTickLabelSpacing": 0
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "exemplar": false,
              "expr": "namespace:instantaneous_transmit_bytes:sum_irate{namespace=~\"$namespace\"}",
              "format": "table",
              "instant": true,
              "legendFormat": "__auto",
              "range": false,
              "refId": "A"
            }
          ],
          "title": "Instantaneous Rate of Bytes Transmitted Per Namespace",
          "type": "barchart"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "iops"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 54
          },
          "id": 233,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_num_write_iops{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_namespace=~\"$namespace\"}) by (pod_namespace)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_namespace}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Write IOPS Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "iops"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 54
          },
          "id": 234,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_num_read_iops{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_namespace=~\"$namespace\"}) by (pod_namespace)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_namespace}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Read IOPS Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "KBs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 64
          },
          "id": 275,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_write_io_bandwidth_k_bps{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_namespace=~\"$namespace\"}) by (pod_namespace)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_namespace}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Write Bandwidth Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "KBs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 64
          },
          "id": 276,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_read_io_bandwidth_k_bps{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_namespace=~\"$namespace\"}) by (pod_namespace)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_namespace}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Read Bandwidth Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "µs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 74
          },
          "id": 277,
          "interval": "15",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_avg_write_io_latency_usecs{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_namespace=~\"$namespace\"}) by (pod_namespace)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_namespace}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Write Latency Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "noValue": "No Volume Groups",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "µs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 74
          },
          "id": 278,
          "interval": "15",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "avg(volume_group_stat_controller_avg_read_io_latency_usecs{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_namespace=~\"$namespace\"}) by (pod_namespace)",
              "hide": false,
              "instant": false,
              "legendFormat": "{{pod_namespace}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average VG Read Latency Per Namespace",
          "type": "timeseries"
        }
      ],
      "title": "Namespaces",
      "type": "row"
    },
    {
      "collapsed": true,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 92
      },
      "id": 210,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "iops"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 9,
            "w": 24,
            "x": 0,
            "y": 6
          },
          "id": 219,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "volume_group_stat_controller_num_iops{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace=~\"$namespace\", node_name=~\"$node\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "pod: {{pod_name}} - pvc: {{pvc_name}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total IOPS",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "KBs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 9,
            "w": 24,
            "x": 0,
            "y": 15
          },
          "id": 214,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "volume_group_stat_controller_io_bandwidth_k_bps{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace=~\"$namespace\", node_name=~\"$node\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "pod: {{pod_name}} - pvc: {{pvc_name}}  ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total IO Bandwidth",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "µs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 9,
            "w": 24,
            "x": 0,
            "y": 24
          },
          "id": 215,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "volume_group_stat_controller_avg_io_latency_usecs{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace=~\"$namespace\", node_name=~\"$node\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "pod: {{pod_name}} - pvc: {{pvc_name}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Total IO Latency",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "iops"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 33
          },
          "id": 211,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "volume_group_stat_controller_num_write_iops{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace=~\"$namespace\", node_name=~\"$node\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "pod: {{pod_name}} - pvc: {{pvc_name}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Write IOPS",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "iops"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 33
          },
          "id": 230,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "volume_group_stat_controller_num_read_iops{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace=~\"$namespace\", node_name=~\"$node\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "pod: {{pod_name}} - pvc: {{pvc_name}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Read IOPS",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "KBs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 43
          },
          "id": 212,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "volume_group_stat_controller_write_io_bandwidth_k_bps{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace=~\"$namespace\", node_name=~\"$node\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "pod: {{pod_name}} - pvc: {{pvc_name}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Write Bandwidth",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "KBs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 43
          },
          "id": 217,
          "interval": "15s",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "volume_group_stat_controller_read_io_bandwidth_k_bps{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace=~\"$namespace\", node_name=~\"$node\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "pod: {{pod_name}} - pvc: {{pvc_name}}  ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Read Bandwidth",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "µs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 53
          },
          "id": 213,
          "interval": "15",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "volume_group_stat_controller_avg_write_io_latency_usecs{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace=~\"$namespace\", node_name=~\"$node\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "pod: {{pod_name}} - pvc: {{pvc_name}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Write Latency",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "axisSoftMin": 0,
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  }
                ]
              },
              "unit": "µs"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 53
          },
          "id": 218,
          "interval": "15",
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "volume_group_stat_controller_avg_read_io_latency_usecs{volumename=~\"$volume_group\"} * on (volumename) group_right() eks_cluster_pod_pvc_info{volumename=~\"$volume_group\", pod_name=~\"$application_pods\", pod_namespace=~\"$namespace\", node_name=~\"$node\"}",
              "hide": false,
              "instant": false,
              "legendFormat": "pod: {{pod_name}} - pvc: {{pvc_name}} ",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Read Latency",
          "type": "timeseries"
        }
      ],
      "title": "Volume Groups",
      "type": "row"
    },
    {
      "collapsed": true,
      "datasource": {
        "type": "prometheus",
        "uid": "${datasource}"
      },
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 93
      },
      "id": 69,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "BANDWIDTH",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 9,
            "w": 24,
            "x": 0,
            "y": 7
          },
          "id": 79,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "multi",
              "sort": "desc"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "sum(rate(container_network_receive_bytes_total[$__rate_interval])) by (namespace)",
              "interval": "$resolution",
              "legendFormat": "Received : {{ namespace }}",
              "range": true,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "expr": "- sum(rate(container_network_transmit_bytes_total[$__rate_interval])) by (namespace)",
              "hide": false,
              "interval": "$resolution",
              "legendFormat": "Transmitted : {{ namespace }}",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "Network Bytes Received Per Namespace",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "BANDWIDTH",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 16
          },
          "id": 80,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "multi",
              "sort": "desc"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "sum(rate(node_network_receive_bytes_total[$__rate_interval])) by (instance)",
              "interval": "$resolution",
              "legendFormat": "Received bytes in {{ instance }}",
              "range": true,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "expr": "- sum(rate(node_network_transmit_bytes_total[$__rate_interval])) by (instance)",
              "hide": false,
              "interval": "$resolution",
              "legendFormat": "Transmitted bytes in {{ instance }}",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "Total Network Bytes Received (with all virtual devices) Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "description": "Dropped noisy virtual devices for readability.",
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "BANDWIDTH",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 16
          },
          "id": 81,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "multi",
              "sort": "desc"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "sum(rate(node_network_receive_bytes_total{device=\"lo\"}[$__rate_interval])) by (instance)",
              "interval": "$resolution",
              "legendFormat": "Received bytes in {{ instance }}",
              "range": true,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "expr": "- sum(rate(node_network_transmit_bytes_total{device=\"lo\"}[$__rate_interval])) by (instance)",
              "hide": false,
              "interval": "$resolution",
              "legendFormat": "Transmitted bytes in {{ instance }}",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "Network Received Bytes (loopback only) Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "description": "Dropped noisy virtual devices for readability.",
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "BANDWIDTH",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "bytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 24
          },
          "id": 56,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "multi",
              "sort": "desc"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "sum(rate(node_network_receive_bytes_total{device!~\"lxc.*|veth.*|lo\"}[$__rate_interval])) by (instance)",
              "interval": "$resolution",
              "legendFormat": "Received bytes in {{ instance }}",
              "range": true,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "expr": "- sum(rate(node_network_transmit_bytes_total{device!~\"lxc.*|veth.*|lo\"}[$__rate_interval])) by (instance)",
              "hide": false,
              "interval": "$resolution",
              "legendFormat": "Transmitted bytes in {{ instance }}",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "Network Bytes Received (without loopback) Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${datasource}"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "DROPPED PACKETS",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 25,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "none"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 24
          },
          "id": 53,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "right",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "multi",
              "sort": "none"
            }
          },
          "pluginVersion": "8.3.3",
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "sum(rate(node_network_receive_drop_total[$__rate_interval]))",
              "interval": "$resolution",
              "legendFormat": "Packets dropped (receive)",
              "range": true,
              "refId": "A"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "editorMode": "code",
              "exemplar": true,
              "expr": "- sum(rate(node_network_transmit_drop_total[$__rate_interval]))",
              "interval": "$resolution",
              "legendFormat": "Packets dropped (transmit)",
              "range": true,
              "refId": "B"
            }
          ],
          "title": "Network Saturation - Packets dropped",
          "type": "timeseries"
        }
      ],
      "title": "Network Stats",
      "type": "row"
    },
    {
      "collapsed": true,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 94
      },
      "id": 108,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 0,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "decbytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 11,
            "w": 12,
            "x": 0,
            "y": 8
          },
          "id": 109,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "disableTextWrap": false,
              "editorMode": "code",
              "expr": "aws_ec2_disk_write_bytes_average{instance_id=~\"$worker_node_instance_id\"}",
              "fullMetaSearch": false,
              "includeNullMetadata": true,
              "instant": false,
              "legendFormat": "{{instance_id}}",
              "range": true,
              "refId": "A",
              "useBackend": false
            }
          ],
          "title": "Average Write Bytes - Instance Storage Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 0,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "decbytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 11,
            "w": 12,
            "x": 12,
            "y": 8
          },
          "id": 111,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "disableTextWrap": false,
              "editorMode": "code",
              "expr": "aws_ec2_disk_read_bytes_average{instance_id=~\"$worker_node_instance_id\"}",
              "fullMetaSearch": false,
              "includeNullMetadata": true,
              "instant": false,
              "legendFormat": "{{instance_id}}",
              "range": true,
              "refId": "A",
              "useBackend": false
            }
          ],
          "title": " Average Read Bytes - Instance Storage Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 0,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "decbytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 11,
            "w": 12,
            "x": 0,
            "y": 19
          },
          "id": 110,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "disableTextWrap": false,
              "editorMode": "code",
              "expr": "aws_ec2_ebswrite_bytes_average{instance_id=~\"$worker_node_instance_id\"}",
              "fullMetaSearch": false,
              "includeNullMetadata": true,
              "instant": false,
              "legendFormat": "{{instance_id}}",
              "range": true,
              "refId": "A",
              "useBackend": false
            }
          ],
          "title": "Average Write Bytes - EBS Volumes Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 0,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "decbytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 11,
            "w": 12,
            "x": 12,
            "y": 19
          },
          "id": 141,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "disableTextWrap": false,
              "editorMode": "code",
              "expr": "aws_ec2_disk_read_bytes_average{instance_id=~\"$worker_node_instance_id\"}",
              "fullMetaSearch": false,
              "includeNullMetadata": true,
              "instant": false,
              "legendFormat": "{{instance_id}}",
              "range": true,
              "refId": "A",
              "useBackend": false
            }
          ],
          "title": "Average Read Bytes - EBS Volumes Per Worker Node",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "hue",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "decbytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 0,
            "y": 30
          },
          "id": 144,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "aws_ebs_volume_write_bytes_average{volume_id=~\"$ebs_volume_id\"}",
              "instant": false,
              "legendFormat": "{{volume_id}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average Write Bytes Per EBS Volume",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "hue",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "decbytes"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 10,
            "w": 12,
            "x": 12,
            "y": 30
          },
          "id": 143,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "aws_ebs_volume_read_bytes_average{volume_id=~\"$ebs_volume_id\"}",
              "instant": false,
              "legendFormat": "{{volume_id}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average Read Bytes Per EBS Volume",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineStyle": {
                  "fill": "solid"
                },
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "iops"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 11,
            "w": 12,
            "x": 0,
            "y": 40
          },
          "id": 173,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "(aws_ebs_volume_read_ops_average{volume_id=~\"$ebs_volume_id\"} + aws_ebs_volume_write_ops_average {volume_id=~\"$ebs_volume_id\"})/(60 - aws_ebs_volume_idle_time_average{volume_id=~\"$ebs_volume_id\"})",
              "instant": false,
              "legendFormat": "{{volume_id}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average IOPS Per EBS Volume",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisBorderShow": false,
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 8,
                "gradientMode": "opacity",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "insertNulls": false,
                "lineInterpolation": "linear",
                "lineStyle": {
                  "fill": "solid"
                },
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green"
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              },
              "unit": "ms"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 11,
            "w": 12,
            "x": 12,
            "y": 40
          },
          "id": 175,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "maxHeight": 600,
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "editorMode": "code",
              "expr": "((aws_ebs_volume_total_read_time_average{volume_id=~\"$ebs_volume_id\"} + aws_ebs_volume_total_write_time_average{volume_id=~\"$ebs_volume_id\"}) * 1000)/(aws_ebs_volume_read_ops_average{volume_id=~\"$ebs_volume_id\"} + aws_ebs_volume_write_ops_average {volume_id=~\"$ebs_volume_id\"})",
              "instant": false,
              "legendFormat": "{{volume_id}}",
              "range": true,
              "refId": "A"
            }
          ],
          "title": "Average Latency Per EBS Volume",
          "type": "timeseries"
        }
      ],
      "title": "Cloudwatch Metrics",
      "type": "row"
    }
  ],
  "refresh": "",
  "schemaVersion": 39,
  "tags": [
    "kubernetes",
    "prometheus",
    "cadvisor"
  ],
  "templating": {
    "list": [
      {
        "current": {
          "selected": false,
          "text": "cn-aos-demo",
          "value": "cn-aos-demo"
        },
        "datasource": {
          "type": "prometheus",
          "uid": "prometheus"
        },
        "definition": "label_values(eks_cluster_metadata_info,eks_cluster_name)",
        "hide": 0,
        "includeAll": false,
        "label": "EKS Cluster ",
        "multi": false,
        "name": "eks_cluster",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(eks_cluster_metadata_info,eks_cluster_name)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "type": "query"
      },
      {
        "current": {
          "selected": true,
          "text": [
            "All"
          ],
          "value": [
            "$__all"
          ]
        },
        "datasource": {
          "type": "prometheus",
          "uid": "${datasource}"
        },
        "definition": "label_values(ncs_cluster_info,name)",
        "hide": 0,
        "includeAll": true,
        "label": "NCS Cluster ",
        "multi": true,
        "name": "ncs_cluster",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(ncs_cluster_info,name)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "type": "query"
      },
      {
        "allValue": ".+",
        "current": {
          "selected": true,
          "text": [
            "All"
          ],
          "value": [
            "$__all"
          ]
        },
        "datasource": {
          "type": "prometheus",
          "uid": "prometheus"
        },
        "definition": "label_values(kube_pod_info,namespace)",
        "hide": 0,
        "includeAll": true,
        "label": "Namespace",
        "multi": true,
        "name": "namespace",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(kube_pod_info,namespace)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 1,
        "type": "query"
      },
      {
        "allValue": "",
        "current": {
          "selected": true,
          "text": [
            "All"
          ],
          "value": [
            "$__all"
          ]
        },
        "datasource": {
          "type": "prometheus",
          "uid": "prometheus"
        },
        "definition": "label_values(kube_pod_info{namespace=~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"},pod)",
        "hide": 0,
        "includeAll": true,
        "label": "NCS System Pods",
        "multi": true,
        "name": "ncs_pods",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(kube_pod_info{namespace=~\"ncs-system|ntnx-system|ncs-cluster-operator-system|monitoring\"},pod)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "type": "query"
      },
      {
        "allValue": "",
        "current": {
          "selected": true,
          "text": [
            "All"
          ],
          "value": [
            "$__all"
          ]
        },
        "datasource": {
          "type": "prometheus",
          "uid": "${datasource}"
        },
        "definition": "label_values(kube_pod_info{namespace!~\"ncs-system|ncs-cluster-operator-system|monitoring|ntnx-system\"},pod)",
        "hide": 0,
        "includeAll": true,
        "label": "Application Pods",
        "multi": true,
        "name": "application_pods",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(kube_pod_info{namespace!~\"ncs-system|ncs-cluster-operator-system|monitoring|ntnx-system\"},pod)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 1,
        "type": "query"
      },
      {
        "current": {
          "selected": true,
          "text": [
            "All"
          ],
          "value": [
            "$__all"
          ]
        },
        "datasource": {
          "type": "prometheus",
          "uid": "${datasource}"
        },
        "definition": "label_values(kube_node_info,node)",
        "hide": 0,
        "includeAll": true,
        "label": "Worker Nodes",
        "multi": true,
        "name": "node",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(kube_node_info,node)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 2,
        "regex": "",
        "skipUrlSync": false,
        "sort": 1,
        "type": "query"
      },
      {
        "allValue": "",
        "current": {
          "selected": true,
          "text": [
            "All"
          ],
          "value": [
            "$__all"
          ]
        },
        "datasource": {
          "type": "prometheus",
          "uid": "${datasource}"
        },
        "definition": "label_values(node_uname_info{nodename=~\"$node\"},instance)",
        "hide": 0,
        "includeAll": true,
        "label": "Instance",
        "multi": true,
        "name": "instance",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(node_uname_info{nodename=~\"$node\"},instance)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 2,
        "regex": "",
        "skipUrlSync": false,
        "sort": 1,
        "type": "query"
      },
      {
        "current": {
          "selected": false,
          "text": "30s",
          "value": "30s"
        },
        "hide": 0,
        "includeAll": false,
        "multi": false,
        "name": "resolution",
        "options": [
          {
            "selected": false,
            "text": "1s",
            "value": "1s"
          },
          {
            "selected": false,
            "text": "15s",
            "value": "15s"
          },
          {
            "selected": true,
            "text": "30s",
            "value": "30s"
          },
          {
            "selected": false,
            "text": "1m",
            "value": "1m"
          },
          {
            "selected": false,
            "text": "3m",
            "value": "3m"
          },
          {
            "selected": false,
            "text": "5m",
            "value": "5m"
          }
        ],
        "query": "1s, 15s, 30s, 1m, 3m, 5m",
        "queryValue": "",
        "skipUrlSync": false,
        "type": "custom"
      },
      {
        "current": {
          "selected": false,
          "text": "All",
          "value": "$__all"
        },
        "datasource": {
          "type": "prometheus",
          "uid": "${datasource}"
        },
        "definition": "label_values(aws_ec2_cpuutilization_average,instance_id)",
        "hide": 0,
        "includeAll": true,
        "label": "Worker Node ID",
        "multi": false,
        "name": "worker_node_instance_id",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(aws_ec2_cpuutilization_average,instance_id)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "type": "query"
      },
      {
        "current": {
          "selected": false,
          "text": "Prometheus",
          "value": "prometheus"
        },
        "hide": 0,
        "includeAll": false,
        "label": "Datasource",
        "multi": false,
        "name": "datasource",
        "options": [],
        "query": "prometheus",
        "queryValue": "",
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "type": "datasource"
      },
      {
        "allValue": ".+",
        "current": {
          "selected": true,
          "text": [
            "All"
          ],
          "value": [
            "$__all"
          ]
        },
        "datasource": {
          "type": "prometheus",
          "uid": "prometheus"
        },
        "definition": "label_values(aws_ebs_volume_read_bytes_average,volume_id)",
        "hide": 0,
        "includeAll": true,
        "label": "EBS Volume ID",
        "multi": true,
        "name": "ebs_volume_id",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(aws_ebs_volume_read_bytes_average,volume_id)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "type": "query"
      },
      {
        "allValue": ".+",
        "current": {
          "selected": true,
          "text": [
            "All"
          ],
          "value": [
            "$__all"
          ]
        },
        "datasource": {
          "type": "prometheus",
          "uid": "prometheus"
        },
        "definition": "label_values(volume_group_stat_controller_avg_io_latency_usecs,volume_group_name)",
        "hide": 0,
        "includeAll": true,
        "label": "Volume Group",
        "multi": true,
        "name": "volume_group",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values(volume_group_stat_controller_avg_io_latency_usecs,volume_group_name)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "type": "query"
      },
      {
        "current": {
          "selected": false,
          "text": "aos-sc-95m2ewnh",
          "value": "aos-sc-95m2ewnh"
        },
        "datasource": {
          "type": "prometheus",
          "uid": "prometheus"
        },
        "definition": "label_values({namespace=\"ncs-system\", pod=~\"aos-sc.+\"},pod)",
        "hide": 2,
        "includeAll": false,
        "multi": false,
        "name": "aos_pods",
        "options": [],
        "query": {
          "qryType": 1,
          "query": "label_values({namespace=\"ncs-system\", pod=~\"aos-sc.+\"},pod)",
          "refId": "PrometheusVariableQueryEditor-VariableQuery"
        },
        "refresh": 1,
        "regex": "",
        "skipUrlSync": false,
        "sort": 0,
        "type": "query"
      }
    ]
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timeRangeUpdatedDuringEditOrView": false,
  "timepicker": {},
  "timezone": "",
  "title": "CN AOS  Dashboard",
  "uid": "e1RXnCbVw8",
  "version": 7,
  "weekStart": ""
}
EOF

