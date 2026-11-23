module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  # v21 input syntax: name and kubernetes_version
  name               = local.cluster_name
  kubernetes_version = var.cluster_version

  endpoint_public_access = true

  # Deploy into VPC private app subnets
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Modern EKS Access Entries (replaces legacy aws-auth ConfigMap)
  enable_cluster_creator_admin_permissions = true

  # Managed EKS Add-ons (v21 uses `addons`)
  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
  }

  # EKS Managed Node Group
  eks_managed_node_groups = {
    app_nodes = {
      instance_types = ["t3.medium"]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size     = 1
      desired_size = 2
      max_size     = 3

      subnet_ids = module.vpc.private_subnets

      labels = {
        Environment = var.environment
        Role        = "worker-nodes"
      }

      tags = {
        Environment = var.environment
        Terraform   = "true"
      }
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
