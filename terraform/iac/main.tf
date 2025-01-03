
# VPC resource 
# 1
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name        = "${local.Eks_name}-${local.Env}-VPC"
    Environment = local.Env
    Owner       = local.Owner
  }
}
# Internet gateway (IG) resource
# 2
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name        = "${local.Eks_name}-${local.Env}-IGW"
    Environment = local.Env
    Owner       = local.Owner
  }
}
# Subnets resources
# 3
# public subnets
resource "aws_subnet" "public_zone1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.cidr_block_pubsn1
  availability_zone       = local.Az1
  map_public_ip_on_launch = true
  tags = {
    "Name"                                                 = "public-subnet-${local.Az1}-${local.Env}-${local.Eks_name}"
    "kubernetes.io/role/elb"                               = "1"
    "kubernetes.io/cluster/${local.Env}-${local.Eks_name}" = "owned"
    Owner                                                  = local.Owner
  }
}

resource "aws_subnet" "public_zone2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.cidr_block_pubsn2
  availability_zone       = local.Az2
  map_public_ip_on_launch = true
  tags = {
    "Name"                                                 = "public-subnet-${local.Az2}-${local.Env}-${local.Eks_name}"
    "kubernetes.io/role/elb"                               = "1"
    "kubernetes.io/cluster/${local.Env}-${local.Eks_name}" = "owned"
    Owner                                                  = local.Owner
  }
}
# private subnets
resource "aws_subnet" "private_zone1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.cidr_block_privsn1
  availability_zone = local.Az1
  tags = {
    "Name"                                                 = "private-subnet-${local.Az1}-${local.Env}-${local.Eks_name}"
    "kubernetes.io/role/internal-elb"                      = "1"
    "kubernetes.io/cluster/${local.Env}-${local.Eks_name}" = "owned"
    Owner                                                  = local.Owner
  }
}

resource "aws_subnet" "private_zone2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.cidr_block_privsn2
  availability_zone = local.Az2
  tags = {
    "Name"                                                 = "private-subnet-${local.Az2}-${local.Env}-${local.Eks_name}"
    "kubernetes.io/role/internal-elb"                      = "1"
    "kubernetes.io/cluster/${local.Env}-${local.Eks_name}" = "owned"
    Owner                                                  = local.Owner
  }
}
# NAT Gateway resources
# 4
# AWS Elastic IP
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name  = "${local.Eks_name}-${local.Env}-EIP"
    Owner = local.Owner
  }
}
# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_zone1.id
  tags = {
    Name  = "${local.Eks_name}-${local.Env}-NAT"
    Owner = local.Owner
  }
  depends_on = [aws_internet_gateway.igw]
}
# Route Tables
# 5
# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = var.cidr_block_public_rt
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name  = "${local.Eks_name}-${local.Env}-public-RT"
    Owner = local.Owner
  }
}
# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = var.cidr_block_private_rt
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name  = "${local.Eks_name}-${local.Env}-private-RT"
    Owner = local.Owner
  }
}
# Route table associations
# 6
# for public subnets
resource "aws_route_table_association" "public_zone1" {
  subnet_id      = aws_subnet.public_zone1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_zone2" {
  subnet_id      = aws_subnet.public_zone2.id
  route_table_id = aws_route_table.public.id
}
# for private subnets
resource "aws_route_table_association" "private_zone1" {
  subnet_id      = aws_subnet.private_zone1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_zone2" {
  subnet_id      = aws_subnet.private_zone2.id
  route_table_id = aws_route_table.private.id
}
#!!! EKS (elastic kubernetes service)
# 7
resource "aws_iam_role" "eks" {
  name               = "${local.Eks_name}-${local.Env}-cluster"
  assume_role_policy = file("../iam/policies/EKS-CLUSTER-eks-aim-role.json")
}

resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_eks_cluster" "eks" {
  name     = "${local.Eks_name}-${local.Env}"
  version  = local.Eks_version
  role_arn = aws_iam_role.eks.arn
  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids = [
      aws_subnet.private_zone1.id,
      aws_subnet.private_zone2.id
    ]
  }
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
  depends_on = [aws_iam_role_policy_attachment.eks]
}
# Nodes EKS
# 8
resource "aws_iam_role" "nodes" {
  name               = "${local.Eks_name}-${local.Env}-nodes"
  assume_role_policy = file("../iam/policies/EKS-PROD-nodes.json")
}
# This policy now includes AssumeRoleForPodIdentity for the Pod Identity Agent
resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.eks.name
  version         = local.Eks_version
  node_group_name = "general"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids = [
    aws_subnet.private_zone1.id,
    aws_subnet.private_zone2.id
  ]
  # Most likely, you want ON_DEMAND
  capacity_type  = "SPOT"
  instance_types = ["t3.medium"]
  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }
  update_config {
    max_unavailable = 1
  }
  labels = {
    role = "general"
  }
  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
  ]
  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# pod identity addon
# 10
resource "aws_eks_addon" "pod_identity" {
  cluster_name  = aws_eks_cluster.eks.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.3.4-eksbuild.1"
}
# HELM argocd
# 11
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.3.11"
  values           = [file("../values/argocd.yaml")]
  depends_on       = [aws_eks_node_group.general]
}
# image updater
# 12
resource "aws_iam_role" "argocd_image_updater" {
  name               = "${aws_eks_cluster.eks.name}-argocd-image-updater"
  assume_role_policy = data.aws_iam_policy_document.argocd_image_updater.json
}

resource "aws_iam_role_policy_attachment" "argocd_image_updater" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.argocd_image_updater.name
}

resource "aws_eks_pod_identity_association" "argocd_image_updater" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "argocd"
  service_account = "argocd-image-updater"
  role_arn        = aws_iam_role.argocd_image_updater.arn
}

resource "helm_release" "updater" {
  name             = "updater"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-image-updater"
  namespace        = "argocd"
  create_namespace = true
  version          = "0.11.0"
  values           = [file("../values/image-updater.yaml")]
  depends_on       = [helm_release.argocd]
}
# HELM metrics server
# 13
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"
  values     = [file("../values/metrics-server.yaml")]
  depends_on = [aws_eks_node_group.general]
}
# cluster autoescaler
# 14
resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${aws_eks_cluster.eks.name}-cluster-autoscaler"
  assume_role_policy = file("../iam/policies/EKS-cluster-autoescaler.json")
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name   = "${aws_eks_cluster.eks.name}-cluster-autoscaler"
  policy = file("../iam/AWSAutoScaling.json")
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler.arn
}

resource "helm_release" "cluster_autoscaler" {
  name       = "autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.37.0"
  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }
  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.eks.name
  }
  # MUST be updated to match your region 
  set {
    name  = "awsRegion"
    value = local.Region
  }
  depends_on = [helm_release.metrics_server]
}
# Load balancer controller
# 15
resource "aws_iam_role" "aws_lbc" {
  name               = "${aws_eks_cluster.eks.name}-aws-lbc"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc.json
}

resource "aws_iam_policy" "aws_lbc" {
  policy = file("../iam/AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerController"
}

resource "aws_iam_role_policy_attachment" "aws_lbc" {
  policy_arn = aws_iam_policy.aws_lbc.arn
  role       = aws_iam_role.aws_lbc.name
}

resource "aws_eks_pod_identity_association" "aws_lbc" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_lbc.arn
}

resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"
  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks.name
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }
  depends_on = [helm_release.cluster_autoscaler]
}
# open id connect provider
# 16
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
  depends_on      = [helm_release.cluster_autoscaler]
}
# EFS
# 17
resource "aws_efs_file_system" "eks" {
  creation_token   = "eks"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true
  # lifecycle_policy {
  #   transition_to_ia = "AFTER_30_DAYS"
  # }
}

resource "aws_efs_mount_target" "zone_a" {
  file_system_id  = aws_efs_file_system.eks.id
  subnet_id       = aws_subnet.private_zone1.id
  security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
  depends_on      = [aws_iam_openid_connect_provider.eks]
}

resource "aws_efs_mount_target" "zone_b" {
  file_system_id  = aws_efs_file_system.eks.id
  subnet_id       = aws_subnet.private_zone2.id
  security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
  depends_on      = [aws_iam_openid_connect_provider.eks]
}
# CSI
# 18
resource "aws_iam_role" "efs_csi_driver" {
  name               = "${aws_eks_cluster.eks.name}-efs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_driver.json
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_driver.name
}

resource "helm_release" "efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  namespace  = "kube-system"
  version    = "3.0.5"
  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }
  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.efs_csi_driver.arn
  }
  depends_on = [
    aws_efs_mount_target.zone_a,
    aws_efs_mount_target.zone_b
  ]
}

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }
  storage_provisioner = "efs.csi.aws.com"
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.eks.id
    directoryPerms   = "700"
  }
  mount_options = ["iam"]
  depends_on    = [helm_release.efs_csi_driver]
}