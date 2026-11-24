# Stage 1: Production-Grade AWS Infrastructure for Self-Managed Vanilla Kubernetes

Production-grade, modular Terraform repository provisioning the underlying AWS infrastructure for a self-managed Vanilla Kubernetes (`kubeadm`) cluster hosting a decoupled 2-service microservices application (`task-service` on port 3000, `stats-service` on port 4000, and PostgreSQL on port 5432).

> **Architectural Boundary Rule:**
> Stage 2 (Ansible) configures 100% of the operating system, `containerd`, `kubeadm`, and cluster networking over AWS Systems Manager (SSM). No Docker or Kubernetes installation scripts are executed in EC2 `user_data`.

---

## 1. Architecture Overview

```
                                      AWS Region: ap-southeast-2
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ Custom Multi-AZ VPC (10.0.0.0/16)                                                                      │
 │                                                                                                        │
 │  ┌────────────────────── Public Subnets (10.0.1.0/24, 10.0.2.0/24) ─────────────────────────────────┐  │
 │  │ Internet Gateway ◄──► [ Public Application Load Balancer (Port 80) ] ◄──► [ Single NAT Gateway ]  │  │
 │  │                              │ Forward all traffic (/*)                                          │  │
 │  │                              ▼                                                                   │  │
 │  │                 [ Target Group: k8s-ingress-tg (Port 30080, Health: /healthz) ]                  │  │
 │  └──────────────────────────────┼──────────────────────────────────┼────────────────────────────────┘  │
 │                                 │                                  │                                   │
 │  ┌──────────────────────────────┼── Private App Subnets (10.0.10.0/24, 10.0.11.0/24) ─────────────┐  │
 │  │                              │ NodePort TCP 30080 (ALB SG only)                                 │  │
 │  │                              ▼                                  ▼                                │  │
 │  │                     [ prod-k8s-worker-1 ]              [ prod-k8s-worker-2 ]                     │  │
 │  │                     (t3.small, AZ-a)                   (t3.small, AZ-b)                          │  │
 │  │                     ├── Target Group Member            ├── Target Group Member                   │  │
 │  │                     └── source_dest_check = false      └── source_dest_check = false             │  │
 │  │                              ▲                                  ▲                                │  │
 │  │                              └──────────────────┬───────────────┘                                │  │
 │  │                                                 │ Internal Cluster Ports (6443, etcd,            │  │
 │  │                                                 │ 10250-10259, 30000-32767, BGP, VXLAN)          │  │
 │  │                                                 ▼                                                │  │
 │  │                                      [ prod-k8s-master ]                                         │  │
 │  │                                      (c7i-flex.large, AZ-a)                                      │  │
 │  │                                      └── source_dest_check = false                               │  │
 │  │                                                                                                  │  │
 │  │  IAM Instance Profile: SSM Managed Instance Core + ECR ReadOnly + S3 Artifactory (Ansible)      │  │
 │  └──────────────────────────────────────────────┼───────────────────────────────────────────────────┘  │
 │                                                 │ Inbound TCP 5432 (Restricted K8s Node SG Only)       │
 │  ┌──────────────────────────────────────────────┼───────────────────────────────────────────────────┐  │
 │  │                                              ▼                                                   │  │
 │  │  ┌──────────────── Isolated Database Subnets (10.0.20.0/24, 10.0.21.0/24) ────────────────────┐   │  │
 │  │  │ Amazon RDS PostgreSQL 16 (db.t3.micro, 20GB gp3, Storage Encrypted, Non-Public)            │   │  │
 │  │  │ Master credentials managed automatically via AWS Secrets Manager                           │   │  │
 │  │  └────────────────────────────────────────────────────────────────────────────────────────────┘   │  │
 │  └──────────────────────────────────────────────────────────────────────────────────────────────────┘  │
 └────────────────────────────────────────────────────────────────────────────────────────────────────────┘

 Supporting Stage 1 Components:
  ├── Amazon ECR: Immutable repositories for task-service & stats-service (10 image retention)
  └── AWS SSM Parameter Store: Automated handoff to Stage 2 (Ansible) & Stage 3 (CI/CD / Helm)
```

---

## 2. Directory Structure

```
.
├── .github/
│   └── workflows/
│       └── stage1-terraform.yml # CI/CD for PR plan validation and main branch apply
├── environments/
│   └── prod/
│       ├── backend.tf           # S3 state (e-commerce-artifactory) with native S3 locking
│       ├── main.tf              # Module orchestration & SSM parameter exports
│       ├── outputs.tf           # Production environment outputs
│       ├── terraform.tfvars     # Environment variable inputs
│       └── variables.tf         # Variable declarations & defaults
├── modules/
│   ├── alb/                     # Public ALB forwarding /* to k8s-ingress-tg (port 30080)
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── compute/                 # Master (c7i-flex.large), Workers (t3.small), IAM & ECR
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── database/                # Amazon RDS PostgreSQL 16 in isolated subnets
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── vpc/                     # Multi-AZ VPC, subnets, IGW, and NAT Gateway
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── .gitignore                   # Excludes .tfstate, .terraform/, preserves .terraform.lock.hcl
└── README.md                    # Architecture overview & execution runbook
```

---

## 3. Component Details & Security Controls

### Networking (`modules/vpc`)
- Custom VPC `10.0.0.0/16` across `ap-southeast-2a` and `ap-southeast-2b`.
- 2 Public Subnets (`10.0.1.0/24`, `10.0.2.0/24`), 2 Private App Subnets (`10.0.10.0/24`, `10.0.11.0/24`), and 2 Isolated DB Subnets (`10.0.20.0/24`, `10.0.21.0/24`).
- Single NAT Gateway (`single_nat_gateway = true`) using AWS provider v5 syntax (`domain = "vpc"` on `aws_eip`).

### Public Ingress (`modules/alb`)
- Internet-facing Application Load Balancer listening on port `80`.
- Forwards all incoming traffic (`/*`) to target group `k8s-ingress-tg` on NodePort `30080`.
- Health check configured on `/healthz` (`matcher = "200"`, `interval = 15`, `timeout = 5`, `healthy_threshold = 2`, `unhealthy_threshold = 3`).
- `deregistration_delay = 30` with `lifecycle { create_before_destroy = true }`.

### Kubernetes Compute & IAM (`modules/compute`)
- **Master Node**: 1x `c7i-flex.large` in private app subnet (tagged `Role = "k8s-master"`).
- **Worker Nodes**: 2x `t3.small` across both private app subnets (tagged `Role = "k8s-worker"`).
- All instances run Ubuntu 24.04 LTS (Noble) with `20GB gp3` encrypted root volume, `source_dest_check = false` (required for CNI packet forwarding), and `lifecycle { ignore_changes = [ami] }`.
- **Target Group Attachment**: Only the 2 worker nodes are registered to `k8s-ingress-tg` (port 30080).
- **Security Group**:
  - Inbound NodePort `30080` allowed strictly from the ALB Security Group.
  - Self-referencing rules for Kubernetes internal communication: `6443` (API Server), `2379-2380` (etcd), `10250-10259` (Kubelet), `30000-32767` (NodePorts), `179` (Calico BGP), `4789/UDP` (VXLAN), and `8472/UDP` (Flannel VXLAN).
- **IAM Instance Profile**:
  - `AmazonSSMManagedInstanceCore` (passwordless, keyless Ansible access via SSM).
  - `AmazonEC2ContainerRegistryReadOnly` (pull images from ECR).
  - S3 inline policy granting access to `arn:aws:s3:::e-commerce-artifactory/ansible-ssm/*` and listing `e-commerce-artifactory`.
- **ECR Repositories**: Immutable repositories for `task-service` and `stats-service` with 10-image retention.

### Database Backend (`modules/database`)
- Amazon RDS PostgreSQL 16 (`db.t3.micro`, 20GB gp3, non-public, storage encrypted) in isolated DB subnets.
- Master credentials managed automatically in AWS Secrets Manager (`manage_master_user_password = true`).
- Inbound port `5432` allowed strictly from the Kubernetes Node Security Group.

### Automated Stage 2 & Stage 3 Handoff (SSM Parameter Store)
- `/prod/app/alb_dns`
- `/prod/app/rds_endpoint`
- `/prod/app/ecr_task_repo_url`
- `/prod/app/ecr_stats_repo_url`
- `/prod/k8s/master_private_ip`

---

## 4. Verification & Manual Execution Runbook

### Prerequisites
- Terraform `>= 1.10.0`
- AWS CLI configured with credentials for `ap-southeast-2`
- Existing S3 bucket `e-commerce-artifactory`

### Local Execution Commands

```bash
# 1. Navigate to the production environment
cd environments/prod

# 2. Initialize Terraform (backend validation skipped for local dry-run)
terraform init

# 3. Validate syntax and module wiring
terraform validate

# 4. Review planned infrastructure changes
terraform plan

# 5. Apply infrastructure provisioning
terraform apply
```

---

## 5. CI/CD GitHub Actions Workflow

The repository includes [.github/workflows/stage1-terraform.yml](file:///E:/Antigravity%20Projects/Infrastructure-For-Microservices-App/.github/workflows/stage1-terraform.yml):
- **Pull Request (`main`)**: Runs `terraform fmt -check`, `terraform init`, `terraform validate`, and `terraform plan` using AWS OIDC federation (`AWS_ROLE_ARN`).
- **Push (`main`)**: Deploys via `terraform apply -auto-approve` inside a protected GitHub `production` environment with manual approval gates.

---

## 6. Declarative Jenkins Pipeline (`Jenkinsfile`)

The repository includes a production-grade `Jenkinsfile` at the root designed for Jenkins instances running on AWS EC2 with an attached IAM Instance Profile (zero static access keys):

- **Parameters (`ACTION`)**:
  - `plan`: Generates safe speculative plan (dry-run).
  - `apply`: Generates plan, requests interactive manual approval (15-min timeout), provisions infrastructure, and waits for SSM node readiness.
  - `destroy`: Generates destroy plan, requests interactive manual approval, destroys resources, and verifies zero billable compute remains.
- **Safety Controls**:
  - `disableConcurrentBuilds()` prevents concurrent runs colliding on S3 state lock.
  - Plan artifacts (`tfplan`) are generated and applied without regeneration.
  - Secure cleanup deletes `tfplan` in the `post { always }` block so no sensitive values remain on disk.
- **SSM Readiness Exit Gate**:
  - Upon `apply`, polls AWS EC2 and AWS SSM (up to 5 minutes) until all 3 Kubernetes nodes (`k8s-master`, `k8s-worker-1`, `k8s-worker-2`) report `PingStatus == Online`.
  - Verifies `/prod/app/alb_dns` and `/prod/app/rds_endpoint` exist before handing off to Stage 2 (Ansible).

