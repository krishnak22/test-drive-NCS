#!/bin/bash

# Source the input environment file
source eks_inputs.env

# Define the target directory where the YAML file should be saved
TARGET_DIR="/root"  

# Create the YAML file at the target directory
cat <<EOF > "$TARGET_DIR/bf-operator.yaml"
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: v0.14.0
  name: ncsinfras.ncs.nutanix.com
spec:
  group: ncs.nutanix.com
  names:
    kind: NcsInfra
    listKind: NcsInfraList
    plural: ncsinfras
    singular: ncsinfra
  scope: Namespaced
  versions:
  - name: v1alpha1
    schema:
      openAPIV3Schema:
        description: NcsInfra is the Schema for the ncsinfras API.
        properties:
          apiVersion:
            description: |-
              APIVersion defines the versioned schema of this representation of an object.
              Servers should convert recognized schemas to the latest internal value, and
              may reject unrecognized values.
              More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
            type: string
          kind:
            description: |-
              Kind is a string value representing the REST resource this object represents.
              Servers may infer this from the endpoint the client submits requests to.
              Cannot be updated.
              In CamelCase.
              More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
            type: string
          metadata:
            type: object
          spec:
            description: NcsInfraSpec defines the desired state of NcsInfra.
            properties:
              accountID:
                description: |-
                  AccountID is the Account ID of the Cloud Provider
                  where the NCS Infra will be deployed.
                minLength: 1
                type: string
              kubernetesClusterSpec:
                description: |-
                  KubernetesClusterSpec represents the spec of the Kubernetes cluster
                  in which the NCS Infra will be deployed
                properties:
                  name:
                    description: Name of the Kubernetes cluster
                    minLength: 1
                    type: string
                  platform:
                    description: |-
                      Platform of the Kubernetes cluster represents
                      the cloud provider on which the cluster is running.
                    minLength: 1
                    type: string
                  region:
                    description: Region of the Kubernetes cluster
                    minLength: 1
                    type: string
                required:
                - name
                - platform
                - region
                type: object
              ncsClusterSpec:
                description: NcsClusterSpec represents the spec of the AOS cluster
                properties:
                  availabilityZone:
                    description: |-
                      AvailabilityZone is the availability zone in which the AOS cluster
                      will be deployed
                    maxLength: 63
                    minLength: 1
                    type: string
                  name:
                    description: Name of the cluster
                    maxLength: 63
                    minLength: 1
                    pattern: '[a-z0-9]([-a-z0-9]*[a-z0-9])?'
                    type: string
                  nodeCount:
                    description: NodeCount is the number of nodes in the AOS cluster
                    format: int32
                    maximum: 15
                    minimum: 1
                    type: integer
                  replicationFactor:
                    description: Replication Factor provides a number of data copies
                      on an AOS cluster
                    format: int32
                    minimum: 1
                    type: integer
                required:
                - availabilityZone
                - name
                - nodeCount
                - replicationFactor
                type: object
              platformParameters:
                description: |-
                  PlatformParameters represent the Platform specific parameters
                  required to deploy the NCS Infra
                properties:
                  aws:
                    description: AWS represents the AWS specific parameters
                    properties:
                      tags:
                        additionalProperties:
                          type: string
                        description: |-
                          Tags represents the tags that will be applied to the resources
                          created by the NCS Infra
                        type: object
                    type: object
                type: object
              subnetSpec:
                description: SubnetSpec represents the spec of the subnets used to
                  deploy the NCS Infra
                properties:
                  aosSubnetCidr:
                    description: |-
                      AOS Subnet CIDR represents the CIDR block of the subnet
                      used to deploy the AOS Pods.
                      This will Create a subnet in the VPC with the specified CIDR block in
                      AWS environment if not already present.
                      If not provided, the Logic will scan the VPC and use the
                      first available desired IP range to create the subnet.
                    type: string
                  loadBalancerSubnetCIDR:
                    description: |-
                      LoadBalancerSubnetCIDR represents the CIDR block of the subnet
                      used to deploy the LoadBalancers for nxctl and other services.
                      This will Create a subnet in the VPC with the specified CIDR block in
                      AWS environment if not already present.
                      Either this or LoadBalancerSubnetID should be provided.
                    type: string
                  loadBalancerSubnetID:
                    description: |-
                      LoadBalancerSubnetID represents the ID of the subnet used to deploy
                      the LoadBalancers for nxctl and other services.
                      This will use the existing subnet with the specified ID in the VPC.
                      Either this or LoadBalancerSubnetCIDR should be provided.
                    type: string
                type: object
              version:
                description: |-
                  Version of the NCS Infra
                  This is the Manifest version of the NCS
                minLength: 1
                type: string
            required:
            - accountID
            - kubernetesClusterSpec
            - ncsClusterSpec
            - version
            type: object
          status:
            description: NcsInfraStatus defines the observed state of NcsInfra.
            properties:
              status:
                description: Status of the NCS Infra
                type: string
              uuid:
                description: UUID of the NCS Infra
                type: string
            required:
            - status
            - uuid
            type: object
        type: object
    served: true
    storage: true
    subresources:
      status: {}
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: v0.14.0
  name: workernodes.ncs.nutanix.com
spec:
  group: ncs.nutanix.com
  names:
    kind: WorkerNode
    listKind: WorkerNodeList
    plural: workernodes
    singular: workernode
  scope: Cluster
  versions:
  - name: v1alpha1
    schema:
      openAPIV3Schema:
        description: WorkerNode is the Schema for the workernodes API.
        properties:
          apiVersion:
            description: |-
              APIVersion defines the versioned schema of this representation of an object.
              Servers should convert recognized schemas to the latest internal value, and
              may reject unrecognized values.
              More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
            type: string
          kind:
            description: |-
              Kind is a string value representing the REST resource this object represents.
              Servers may infer this from the endpoint the client submits requests to.
              Cannot be updated.
              In CamelCase.
              More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
            type: string
          metadata:
            type: object
          spec:
            description: WorkerNodeSpec defines the desired state of WorkerNode.
            properties:
              accountID:
                description: |-
                  AccountID is the Account ID of the Cloud Provider
                  where the NCS Infra will be deployed.
                minLength: 1
                type: string
              availabilityZone:
                description: |-
                  availabilityZone is the availability zone in which the worker nodes
                  should be provisioned. In AWS this is represented by the AZ in which
                  the EC2 instances in the autoscaling group should be provisioned.
                  Example: "us-west-2a"
                type: string
              clusterName:
                description: |-
                  clusterName is the name of the cluster in which the worker nodes
                  should be provisioned. In AWS this is represented by the name of the
                  EKS cluster.
                type: string
              labels:
                additionalProperties:
                  type: string
                description: |-
                  labels is a map of key value pairs that will be used to label the
                  worker nodes that are provisioned. These labels can be used to
                  identify the worker nodes and to schedule applications on the
                  worker nodes based on the labels.
                  Example: {"env": "prod", "tier": "backend"}
                type: object
              nodeCount:
                description: |-
                  NodeCount is the number of worker nodes that should be provisioned.
                  In AWS this is represented by EC2 instances in an autoscaling group
                  in an EKS NodeGroup.
                maximum: 15
                minimum: 1
                type: integer
              nodePoolName:
                description: |-
                  nodePoolName is the name of the node pool that should be provisioned.
                  In AWS this is represented by the name of the EKS NodeGroup.
                minLength: 1
                type: string
              nodeType:
                description: |-
                  nodeType is the type of worker node that should be provisioned.
                  The nodeType represents the way in which the Nutanix Storage
                  will be provisioned for the applications. The NodeType can
                  be one of the following:
                  1. "StorageOnly" -  These AOS Pods running on these
                  nodes are used to provision storage for
                  applications running on other worker nodes.
                  2. "HCI" - These AOS Pods running on these nodes are used to
                  provision storage for applications running on the same node.
                  In this case the AOS Pod and the application pod run on the same node.
                enum:
                - StorageOnly
                - HCI
                type: string
              platform:
                description: |-
                  Platform is the platform on which the worker nodes should be provisioned.
                  The Platform can be one of the following:
                  1. "AWS" - The worker nodes should be provisioned on AWS.
                type: string
              platformParameters:
                description: |-
                  platformParameters is a map of key value pairs that will be used to
                  specify the platform specific parameters that are required to provision
                  the worker nodes. The platform parameters can be used to specify the
                  instance type, the AMI, the subnet, the security group etc.
                properties:
                  aws:
                    description: WorkerNodeAWSParameters defines the AWS-specific
                      parameters
                    properties:
                      amiReleaseVersion:
                        description: |-
                          amiReleaseVersion is the version of the AMI that should be used to
                          provision the worker nodes. Example: "2.0.6"
                        type: string
                      amiType:
                        description: |-
                          amiType is the family of the AMI that should be used to provision
                          the worker nodes. Example: "AL2_x86_64"
                        type: string
                      instanceType:
                        description: |-
                          instanceType is the type of EC2 instance that should be provisioned
                          for the worker nodes. The instanceType is used to specify the
                          hardware configuration of the EC2 instance that should be provisioned.
                          Example: "m5d.8xlarge"
                        type: string
                      sshKeyPair:
                        description: |-
                          sshKeyPair is the name of the AWS KeyPair that
                          should be used to access the EC2 instances. The SSH key is used to
                          authenticate the user when connecting to the EC2 instances.
                          Example: "my-ssh-key"
                        type: string
                      tags:
                        additionalProperties:
                          type: string
                        description: |-
                          Tags is a map of key value pairs that will be used to tag the
                          worker nodes that are provisioned.
                          Example: {"env": "prod", "tier": "backend"}
                        type: object
                    required:
                    - amiReleaseVersion
                    - amiType
                    - instanceType
                    type: object
                type: object
              subnetCIDR:
                description: |-
                  subnetCIDR is the CIDR block that will be used to create the subnet
                  in which the worker nodes will be provisioned. The subnetCIDR is
                  used to specify the IP address range that will be used to assign
                  IP addresses to the worker nodes.
                type: string
            required:
            - accountID
            - availabilityZone
            - clusterName
            - nodeCount
            - nodePoolName
            - nodeType
            - platform
            type: object
          status:
            description: WorkerNodeStatus defines the observed state of WorkerNode.
            properties:
              nodePoolID:
                description: |-
                  nodePoolID is the ID of the node pool that was provisioned.
                  In AWS this is represented by the ARN of the EKS NodeGroup.
                type: string
              platformStatus:
                description: |-
                  PlatformStatus is a map of key value pairs that will be used
                  to specify the platform specific status of the worker nodes that were
                  provisioned. The platform specific status can be used to specify the
                  the subnet ID, the security group ID etc.
                properties:
                  aws:
                    description: AWSResourceStatus defines the status of the AWS-Cloud
                      specific resources.
                    properties:
                      iamRole:
                        description: |-
                          IAMRole is the IAM role that are assigned to the Nodes
                          Example: "arn:aws:iam::123456789012:role/eksctl-my-cluster-nodegroup-ng-NodeInstanceRole-1GJ1Z2Z2Z2Z2Z"
                        type: string
                      securityGroupID:
                        description: |-
                          securityGroupID is the ID of the security group that was used to
                          provision the worker nodes.
                          Example: "sg-0f9d3b6c7b4f2b3e7"
                        type: string
                      subnetID:
                        description: |-
                          subnetID is the ID of the subnet in which the worker nodes were
                          provisioned.
                          Example: "subnet-0f9d3b6c7b4f2b3e7"
                        type: string
                    required:
                    - iamRole
                    - securityGroupID
                    - subnetID
                    type: object
                type: object
              status:
                description: |-
                  Status is the state of the worker nodes that were provisioned.
                  The Status can be one of the following:
                  1. "Deploying" - The worker nodes are being provisioned.
                  2. "Deployed" - The worker nodes have been provisioned and are active.
                  3. "Failed" - The worker nodes could not be provisioned.
                  4. "Deleting" - The worker nodes are being deleted.
                enum:
                - Deploying
                - Deployed
                - Failed
                - Deleting
                type: string
              uuid:
                description: |-
                  UUID is a unique identifier that is generated for the worker node
                  object. The UUID is used to uniquely identify the worker node object.
                type: string
            required:
            - nodePoolID
            - status
            - uuid
            type: object
        type: object
    served: true
    storage: true
    subresources:
      status: {}

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: ncs-infra-deployment-operator
    app.kubernetes.io/instance: leader-election-role
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: role
    app.kubernetes.io/part-of: ncs-infra-deployment-operator
  name: ncs-infra-deployment-operator-leader-election-role
  namespace: ncs-infra-deployment-operator-system
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - patch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ncs-infra-deployment-operator-manager-role
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  - endpoints
  - namespaces
  - ncsdisks/status
  - nodes
  - persistentvolumeclaims
  - persistentvolumes
  - pods
  - pods/exec
  - secrets
  - services
  - storageclasses
  - serviceaccounts
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - apps
  resources:
  - daemonsets
  verbs:
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - patch
- apiGroups:
  - ncs.nutanix.com
  resources:
  - ncsinfras
  - workernodes
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - ncs.nutanix.com
  resources:
  - ncsinfras/status
  - workernodes/status
  verbs:
  - get
  - patch
  - update
- apiGroups:
  - storage.k8s.io
  resources:
  - csidrivers
  - storageclasses
  verbs:
  - get
  - list
  - create
  - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/component: kube-rbac-proxy
    app.kubernetes.io/created-by: ncs-infra-deployment-operator
    app.kubernetes.io/instance: metrics-reader
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: clusterrole
    app.kubernetes.io/part-of: ncs-infra-deployment-operator
  name: ncs-infra-deployment-operator-metrics-reader
rules:
- nonResourceURLs:
  - /metrics
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/component: kube-rbac-proxy
    app.kubernetes.io/created-by: ncs-infra-deployment-operator
    app.kubernetes.io/instance: proxy-role
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: clusterrole
    app.kubernetes.io/part-of: ncs-infra-deployment-operator
  name: ncs-infra-deployment-operator-proxy-role
rules:
- apiGroups:
  - authentication.k8s.io
  resources:
  - tokenreviews
  verbs:
  - create
- apiGroups:
  - authorization.k8s.io
  resources:
  - subjectaccessreviews
  verbs:
  - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: ncs-infra-deployment-operator
    app.kubernetes.io/instance: leader-election-rolebinding
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: rolebinding
    app.kubernetes.io/part-of: ncs-infra-deployment-operator
  name: ncs-infra-deployment-operator-leader-election-rolebinding
  namespace: ncs-infra-deployment-operator-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ncs-infra-deployment-operator-leader-election-role
subjects:
- kind: ServiceAccount
  name: <insert-service-account-name>
  namespace: ncs-infra-deployment-operator-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: ncs-infra-deployment-operator
    app.kubernetes.io/instance: manager-rolebinding
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: clusterrolebinding
    app.kubernetes.io/part-of: ncs-infra-deployment-operator
  name: ncs-infra-deployment-operator-manager-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ncs-infra-deployment-operator-manager-role
subjects:
- kind: ServiceAccount
  name: <insert-service-account-name>
  namespace: ncs-infra-deployment-operator-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/component: kube-rbac-proxy
    app.kubernetes.io/created-by: ncs-infra-deployment-operator
    app.kubernetes.io/instance: proxy-rolebinding
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: clusterrolebinding
    app.kubernetes.io/part-of: ncs-infra-deployment-operator
  name: ncs-infra-deployment-operator-proxy-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ncs-infra-deployment-operator-proxy-role
subjects:
- kind: ServiceAccount
  name: <insert-service-account-name>
  namespace: ncs-infra-deployment-operator-system

---
apiVersion: v1
kind: Pod
metadata:
  name: ncs-infra-deployment-operator-controller-manager
  namespace: ncs-infra-deployment-operator-system
spec:
  containers:
    - name: manager
      image: 353502843997.dkr.ecr.us-west-2.amazonaws.com/ncs-infra-deployment-operator:working
      command:
        - /manager
      imagePullPolicy: Always
      resources:
        limits:
          cpu: 100m
          memory: 300Mi
        requests:
          cpu: 100m
          memory: 300Mi
  serviceAccountName: <insert-service-accoun-name>
  hostNetwork: true
EOF


