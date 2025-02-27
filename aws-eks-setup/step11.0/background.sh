source eks_inputs.env
Policy_File_1="/root/test-drive-bf-op-1.json"


cat <<EOL > "${Policy_File_1}
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "eks:UntagResource",
                "eks:DeleteAddon",
                "eks:DeleteNodegroup",
                "eks:TagResource"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/primary_owner": "$PRIMARY_OWNER"
                }
            }
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "iam:CreateInstanceProfile",
                "iam:UpdateAssumeRolePolicy",
                "iam:UntagRole",
                "iam:TagRole",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeletePolicy",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:PutRolePolicy",
                "iam:AddRoleToInstanceProfile",
                "iam:PassRole",
                "iam:DetachRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:DeleteOpenIDConnectProvider",
                "iam:DeleteInstanceProfile",
                "iam:DeleteRole",
                "iam:TagPolicy",
                "iam:CreateOpenIDConnectProvider",
                "iam:CreatePolicy",
                "iam:CreateServiceLinkedRole",
                "iam:UntagPolicy",
                "iam:UntagOpenIDConnectProvider",
                "iam:AddClientIDToOpenIDConnectProvider",
                "iam:TagOpenIDConnectProvider",
                "iam:TagInstanceProfile"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:ResourceTag/primary_owner": "$PRIMARY_OWNER"
                }
            }
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": [
                "iam:GetPolicyVersion",
                "iam:ListRoleTags",
                "ecr:DescribeImageReplicationStatus",
                "eks:ListAddons",
                "ecr:DescribeRepositoryCreationTemplates",
                "ecr:ListTagsForResource",
                "ecr:ListImages",
                "ecr:BatchGetRepositoryScanningConfiguration",
                "ecr:GetRegistryScanningConfiguration",
                "eks:DescribeAddon",
                "eks:DescribeNodegroup",
                "iam:ListAttachedRolePolicies",
                "iam:ListOpenIDConnectProviderTags",
                "ecr:DescribeRepositories",
                "eks:DescribeAddonVersions",
                "iam:ListPolicyTags",
                "iam:ListRolePolicies",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetLifecyclePolicy",
                "iam:ListPolicies",
                "ecr:GetRegistryPolicy",
                "iam:GetRole",
                "eks:ListNodegroups",
                "ecr:DescribeImageScanFindings",
                "eks:DescribeAddonConfiguration",
                "iam:GetPolicy",
                "ecr:GetLifecyclePolicyPreview",
                "ecr:GetDownloadUrlForLayer",
                "ecr:DescribeRegistry",
                "ecr:DescribePullThroughCacheRules",
                "ecr:GetAuthorizationToken",
                "iam:ListRoles",
                "sts:*",
                "eks:CreateNodegroup",
                "ecr:ValidatePullThroughCacheRule",
                "ecr:GetAccountSetting",
                "iam:ListPolicyVersions",
                "eks:DescribeIdentityProviderConfig",
                "iam:ListOpenIDConnectProviders",
                "ecr:BatchGetImage",
                "ecr:DescribeImages",
                "eks:CreateAddon",
                "eks:DescribeCluster",
                "eks:ListClusters",
                "iam:GetOpenIDConnectProvider",
                "iam:GetRolePolicy",
                "ecr:GetRepositoryPolicy"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor3",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateLaunchTemplate",
                "ec2:CreatePlacementGroup",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:CreateRouteTable",
                "ec2:AssociateSubnetCidrBlock",
                "ec2:RunInstances",
                "ec2:CreateSubnet",
                "ec2:CreateLaunchTemplateVersion",
                "ec2:AssociateRouteTable"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor4",
            "Effect": "Allow",
            "Action": "ec2:*",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/primary_owner": "$PRIMARY_OWNER"
                }
            }
        },
        {
            "Sid": "VisualEditor5",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:TagResource",
                "s3:PutObjectVersionTagging",
                "s3:PutObjectTagging"
            ],
            "Resource": "arn:aws:s3:::nutanix-ncs-metadata-353502843997/*"
        },
        {
            "Sid": "VisualEditor6",
            "Effect": "Allow",
            "Action": [
                "ec2:GetIpamResourceCidrs",
                "ec2:DescribeCoipPools",
                "ec2:DescribeVerifiedAccessEndpoints",
                "ec2:DescribeLocalGatewayVirtualInterfaces",
                "ec2:DescribeNetworkInsightsPaths",
                "ec2:DescribeHostReservationOfferings",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVolumes",
                "ec2:DescribeFpgaImageAttribute",
                "ec2:GetEbsDefaultKmsKeyId",
                "ec2:DescribeExportTasks",
                "ec2:DescribeTransitGatewayMulticastDomains",
                "ec2:DescribeManagedPrefixLists",
                "ec2:DescribeKeyPairs",
                "ec2:GetVerifiedAccessEndpointPolicy",
                "ec2:DescribeVpcClassicLinkDnsSupport",
                "ec2:DescribeSnapshotAttribute",
                "ec2:DescribeIpamResourceDiscoveryAssociations",
                "ec2:DescribeInstanceEventWindows",
                "ec2:DescribeVolumeAttribute",
                "ec2:DescribeLocalGatewayVirtualInterfaceGroups",
                "ec2:DescribeVpcEndpointServicePermissions",
                "ec2:DescribeTransitGatewayAttachments",
                "ec2:DescribeAddressTransfers",
                "ec2:SearchLocalGatewayRoutes",
                "ec2:DescribeTrunkInterfaceAssociations",
                "ec2:GetSpotPlacementScores",
                "ec2:DescribeInstanceConnectEndpoints",
                "ec2:DescribeFleets",
                "ec2:DescribeAwsNetworkPerformanceMetricSubscriptions",
                "ec2:DescribeCapacityReservationBillingRequests",
                "ec2:GetIpamDiscoveredAccounts",
                "ec2:DescribeCapacityReservationFleets",
                "ec2:DescribeMacHosts",
                "ec2:DescribePrincipalIdFormat",
                "ec2:DescribeFlowLogs",
                "ec2:DescribeRegions",
                "ec2:GetNetworkInsightsAccessScopeAnalysisFindings",
                "ec2:DescribeVpcEndpointServices",
                "ec2:DescribeSpotInstanceRequests",
                "ec2:DescribeVerifiedAccessTrustProviders",
                "ec2:DescribeTransitGatewayRouteTables",
                "ec2:DescribeLocalGatewayRouteTables",
                "ec2:SearchTransitGatewayMulticastGroups",
                "ec2:GetIpamPoolAllocations",
                "ec2:DescribeHostReservations",
                "ec2:GetIpamDiscoveredPublicAddresses",
                "ec2:GetInstanceMetadataDefaults",
                "ec2:DescribeBundleTasks",
                "ec2:DescribeIpamPools",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeStoreImageTasks",
                "ec2:GetIpamAddressHistory",
                "ec2:DescribeIpams",
                "ec2:GetDeclarativePoliciesReportSummary",
                "ec2:DescribeAggregateIdFormat",
                "ec2:GetSnapshotBlockPublicAccessState",
                "ec2:ExportClientVpnClientConfiguration",
                "ec2:GetHostReservationPurchasePreview",
                "ec2:DescribeTransitGatewayConnectPeers",
                "ec2:DescribeNetworkInsightsAnalyses",
                "ec2:DescribePlacementGroups",
                "ec2:DescribeCapacityBlockOfferings",
                "ec2:DescribeInstanceImageMetadata",
                "ec2:DescribeIpamByoasn",
                "ec2:SearchTransitGatewayRoutes",
                "ec2:DescribeSpotDatafeedSubscription",
                "ec2:DescribeNetworkInterfacePermissions",
                "ec2:DescribeReservedInstances",
                "ec2:DescribeEgressOnlyInternetGateways",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:ExportVerifiedAccessInstanceClientConfiguration",
                "ec2:DescribeFleetInstances",
                "ec2:GetTransitGatewayAttachmentPropagations",
                "ec2:DescribeClientVpnTargetNetworks",
                "ec2:DescribeSnapshotTierStatus",
                "ec2:DescribeVpcEndpointServiceConfigurations",
                "ec2:DescribePrefixLists",
                "ec2:GetTransitGatewayRouteTablePropagations",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeVpnGateways",
                "ec2:ListSnapshotsInRecycleBin",
                "ec2:GetResourcePolicy"
            ],
            "Resource": "*"
        }
    ]
}
EOL
