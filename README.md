# AWS Infrastructure for 2-Service Microservice Application

Production-grade, modular Terraform codebase to provision modern cloud infrastructure on Amazon Web Services (AWS) for a decoupled 2-service microservice application (`task-service` and `stats-service`).

---

## 1. Architecture Overview

```
                                      AWS Cloud (ap-southeast-2)
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ VPC: 10.0.0.0/16                                                                                       │
 │                                                                                                        │
 │   ┌────────────────────────── Public Subnets (10.0.1.0/24, 10.0.2.0/24) ───────────────────────────┐    │
 │   │  Internet Gateway ◄───► [ ALB / Ingress ] ◄───► [ Single NAT Gateway (Cost-Optimized) ]       │    │
 │   └───────────────────────────────────────────────────────────────────────────────────────────────┘    │
 │                                                      │                                                 │
 │   ┌────────────────────── Private App Subnets (10.0.10.0/24, 10.0.11.0/24) ────────────────────────┐   │
 │   │  Amazon EKS Cluster (Kubernetes v1.37)                                                         │   │
 │   │   ├── EKS Access Entries (Admin privileges, no legacy aws-auth ConfigMap)                      │   │
 │   │   ├── Managed Add-ons: CoreDNS, Kube-Proxy, VPC-CNI, EKS Pod Identity Agent                    │   │
 │   │   └── Managed Node Group: AL2023_x86_64_STANDARD (t3.medium, min: 1, desired: 2, max: 3)       │   │
 │   │        ├── task-service Pods (:3000)                                                           │   │
 │   │        └── stats-service Pods (:4000)                                                          │   │
 │   └──────────────────────────────────────────────────┬─────────────────────────────────────────────┘   │
 │                                                      │ Port 5432 (Restricted SG)                       │
 │   ┌──────────────────── Private Database Subnets (10.0.20.0/24, 10.0.21.0/24) ────────────────────┐   │
 │   │  Amazon RDS PostgreSQL 16 (db.t4g.micro, 20GB storage, publicly_accessible = false)            │   │
 │   └────────────────────────────────────────────────────────────────────────────────────────────────┘   │
 └────────────────────────────────────────────────────────────────────────────────────────────────────────┘

 Supporting AWS Services:
  ├── Amazon ECR: Immutable repositories for task-service & stats-service with 7-day untagged / 10-tag retention
  └── AWS SSM Parameter Store: Encrypted SecureString holding DATABASE_URL at /microservice-app/dev/database-url
```

---

## 2. Infrastructure Components

- **VPC (`vpc.tf`)**:
  - Module: `terraform-aws-modules/vpc/aws` (~> 5.0)
  - CIDR `10.0.0.0/16` across 2 Availability Zones in `ap-southeast-2`.
  - 2 Public Subnets (`kubernetes.io/role/elb = 1`), 2 Private App Subnets (`kubernetes.io/role/internal-elb = 1`), and 2 Private Database Subnets.
  - Cost-optimized with `enable_nat_gateway = true` and `single_nat_gateway = true`.
- **EKS (`eks.tf`)**:
  - Module: `terraform-aws-modules/eks/aws` (~> 21.0)
  - Uses v21 input syntax (`name`, `kubernetes_version`).
  - Native **EKS Access Entries** (`enable_cluster_creator_admin_permissions = true`), eliminating legacy `aws-auth`.
  - Managed Add-ons: `coredns`, `kube-proxy`, `vpc-cni`, `eks-pod-identity-agent`.
  - 1 Managed Node Group: `t3.medium`, `AL2023_x86_64_STANDARD`, min 1, desired 2, max 3.
  - Cluster provisioning is strictly decoupled from Helm/Kubernetes providers to prevent chicken-and-egg deployment issues.
- **RDS PostgreSQL (`rds.tf`)**:
  - Module: `terraform-aws-modules/rds/aws` (~> 6.0)
  - Engine: PostgreSQL 16 on `db.t4g.micro` with 20 GB GP3 storage.
  - Dedicated Security Group restricting port `5432` ingress strictly to `module.eks.node_security_group_id`.
  - Master password generated via `random_password` without special URL characters (`@`, `/`, `:`).
  - Configured with `skip_final_snapshot = true` and `deletion_protection = false` for clean teardowns in training environments.
- **ECR & SSM (`ecr.tf`)**:
  - 2 Amazon ECR Repositories: `task-service` and `stats-service` with `image_tag_mutability = "IMMUTABLE"` and `scan_on_push = true`.
  - ECR Lifecycle Policy expiring untagged images after 7 days and retaining only the last 10 tagged images.
  - Constructed PostgreSQL `DATABASE_URL` stored securely in AWS Systems Manager (SSM) Parameter Store as `SecureString` under `/${var.project_name}/${var.environment}/database-url`.

---

## 3. Prerequisites

1. **Terraform**: Version `>= 1.10` installed.
2. **AWS CLI**: Version `2.x` installed and authenticated with an AWS account:
   ```bash
   aws sts get-caller-identity
   ```
3. **kubectl**: Installed for interacting with the Kubernetes cluster.
4. **S3 State Bucket**: An S3 bucket in `ap-southeast-2` to store remote state (with versioning enabled).

---

## 4. Deployment Instructions

### Step 1: Configure Remote State
Edit [backend.tf](file:///E:/Antigravity%20Projects/Infrastructure-For-Microservices-App/backend.tf) and replace `REPLACE_WITH_YOUR_TFSTATE_BUCKET` with your actual S3 bucket name:

```hcl
terraform {
  backend "s3" {
    bucket       = "my-unique-tfstate-bucket-name"
    key          = "microservices/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
    encrypt      = true
  }
}
```

*(Note: Terraform 1.10+ uses native S3 locking with `use_lockfile = true`, removing the need for a separate DynamoDB lock table).*

### Step 2: Initialize Terraform
```bash
terraform init
```

### Step 3: Review Plan
Create your `terraform.tfvars` from the example template:
```bash
cp terraform.tfvars.example terraform.tfvars
```
Run `terraform plan`:
```bash
terraform plan -out=tfplan
```

### Step 4: Provision Infrastructure
```bash
terraform apply tfplan
```

### Step 5: Configure kubectl Access
After `terraform apply` finishes, update your local `kubeconfig`:
```bash
aws eks update-kubeconfig --region ap-southeast-2 --name microservice-app-dev-eks
```
Verify cluster connectivity:
```bash
kubectl get nodes
```

---

## 5. Teardown & Clean Up

> [!CAUTION]
> **CRITICAL PRE-TEARDOWN STEP**:
> Before running `terraform destroy`, you **MUST** delete any Kubernetes Ingresses or Services of type `LoadBalancer` that were created inside the cluster:
> ```bash
> kubectl delete ingress --all --all-namespaces
> kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer
> ```
> If AWS ALBs/NLBs created dynamically by Kubernetes controllers are not deleted first, they will hold onto the VPC subnets and cause `terraform destroy` to fail with dependency errors on VPC deletion.

Once all in-cluster load balancers are deleted, run:
```bash
terraform destroy -auto-approve
```
