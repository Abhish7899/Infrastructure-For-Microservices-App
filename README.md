# Stage 1: Production-Grade AWS Infrastructure as Code (Terraform)

Modular Terraform codebase provisioning modern, secure, and cost-optimized AWS cloud infrastructure for a 2-service microservices application (`task-service` on port 3000, `stats-service` on port 4000, and PostgreSQL on port 5432).

---

## 1. Architecture Overview

```
                                      AWS Region: ap-southeast-2
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ Custom Multi-AZ VPC (10.0.0.0/16)                                                                      │
 │                                                                                                        │
 │  ┌────────────────────── Public Subnets (10.0.1.0/24, 10.0.2.0/24) ─────────────────────────────────┐  │
 │  │ Internet Gateway ◄──► [ Public Application Load Balancer (Port 80) ] ◄──► [ Single NAT Gateway ]  │  │
 │  │                              │ Path: /api/tasks/* (Priority 10)                                  │  │
 │  │                              │ Path: /api/stats/* (Priority 20)                                  │  │
 │  └──────────────────────────────┼──────────────────────────────────┼────────────────────────────────┘  │
 │                                 │                                  │                                   │
 │  ┌──────────────────────────────┼── Private App Subnets (10.0.10.0/24, 10.0.11.0/24) ─────────────┐  │
 │  │                              ▼                                  ▼                                │  │
 │  │                     [ App Server 1 (t3.small) ]      [ App Server 2 (t3.small) ]                 │  │
 │  │                     ├── task-service (:3000)         ├── task-service (:3000)                    │  │
 │  │                     └── stats-service (:4000)        └── stats-service (:4000)                   │  │
 │  │                              ▲                                  ▲                                │  │
 │  │                              └───────────────┬──────────────────┘                                │  │
 │  │                       Internal Port 3000: stats-service calls task-service                       │  │
 │  │                       IAM Role: SSM Managed Instance Core (Passwordless Ansible) + ECR ReadOnly  │  │
 │  └──────────────────────────────────────────────┼───────────────────────────────────────────────────┘  │
 │                                                 │ Inbound TCP 5432 (Restricted App SG Only)            │
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
  └── AWS SSM Parameter Store: Automated handoff to Stage 2 & Stage 3 (/prod/app/*)
```

---

## 2. Modular Directory Layout

```
.
├── .github/
│   └── workflows/
│       └── stage1-terraform.yml # CI/CD for PR plan validation and main branch apply
├── environments/
│   └── prod/
│       ├── backend.tf           # S3 state (e-commerce-artifactory) with native S3 locking
│       ├── main.tf              # Module orchestrator + SSM parameter exports
│       ├── outputs.tf           # Production environment outputs
│       ├── terraform.tfvars     # Environment variable inputs
│       └── variables.tf         # Variable declarations & defaults
├── modules/
│   ├── alb/                     # Internet-facing ALB with path-based routing rules
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── compute/                 # Private EC2 instances, IAM SSM profile, and ECR repos
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
├── .gitignore                   # Excludes .tfstate, .terraform/, but preserves lockfile
└── README.md                    # Architecture summary & runbook
```

---

## 3. Key Design Decisions & Security Controls

1. **Zero Hardcoded Secrets & Dynamic AMI Resolution**:
   - Ubuntu 24.04 LTS (Noble) is resolved dynamically via Canonical's owner ID (`099720109477`) with `lifecycle { ignore_changes = [ami] }`.
   - RDS master password uses `manage_master_user_password = true`, automatically stored in AWS Secrets Manager.
2. **Secure Keyless Access (AWS Systems Manager)**:
   - EC2 instances are in private subnets with NO public IPs and NO open SSH port `22`.
   - EC2 IAM role includes `AmazonSSMManagedInstanceCore` allowing Stage 2 Ansible to configure nodes over AWS SSM Session Manager.
3. **Defense-in-Depth Security Groups**:
   - **ALB SG**: Inbound HTTP port `80` from `0.0.0.0/0`.
   - **App SG**: Inbound ports `3000` and `4000` ONLY from the ALB SG, plus self-referencing port `3000` so `stats-service` can reach `task-service` internally.
   - **DB SG**: Inbound PostgreSQL port `5432` ONLY from the App SG.
4. **Automated Stage 2 / Stage 3 Handoff (SSM Parameter Store)**:
   - Output values are published under `/${var.environment}/app/*` so subsequent Ansible playbooks and deployment pipelines can fetch them dynamically:
     - `/prod/app/alb_dns`
     - `/prod/app/rds_endpoint`
     - `/prod/app/ecr_task_repo_url`
     - `/prod/app/ecr_stats_repo_url`

---

## 4. How to Run Stage 1

### Prerequisites
- Terraform `>= 1.10.0`
- AWS CLI `v2.x` configured with credentials for `ap-southeast-2`
- Existing S3 bucket `e-commerce-artifactory` for remote state storage

### Local Execution Runbook

```bash
# 1. Navigate to the production environment
cd environments/prod

# 2. Initialize Terraform (downloads AWS provider ~> 5.0 and modules)
terraform init

# 3. Validate syntax and configuration
terraform validate

# 4. Review execution plan
terraform plan

# 5. Apply infrastructure provisioning
terraform apply
```

---

## 5. CI/CD GitHub Actions Workflow

The repository includes [stage1-terraform.yml](file:///E:/Antigravity%20Projects/Infrastructure-For-Microservices-App/.github/workflows/stage1-terraform.yml):
- **Pull Request (`main`)**: Runs `terraform fmt -check`, `terraform init`, `terraform validate`, and `terraform plan` using AWS OIDC federation (no permanent IAM keys stored in GitHub).
- **Push (`main`)**: Deploys via `terraform apply -auto-approve` inside a protected GitHub `production` environment with manual approval gates.
