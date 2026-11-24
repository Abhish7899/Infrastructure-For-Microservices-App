// =============================================================================
// Stage 1 Declarative Jenkins Pipeline: AWS Infrastructure Automation (Terraform)
// =============================================================================
// Features:
// 1. Zero Static Credentials - Uses IAM Instance Profile attached to Jenkins EC2
// 2. Terraform S3 Backend with Native S3 Locking (requires Terraform >= 1.10.0)
// 3. Plan-First Architecture with interactive Manual Approval Gate
// 4. Safe Teardown Protection for 'destroy' action
// 5. Automated Post-Apply SSM Readiness Polling (verifies 3 K8s nodes online)
// 6. Post-Destroy Billing Teardown Verification
// 7. Zero Residual Secrets - Plan artifacts securely pruned in post block
// =============================================================================

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Select Terraform action: plan (safe dry-run), apply (provision), or destroy (teardown)'
        )
    }

    environment {
        AWS_REGION       = 'ap-southeast-2'
        TF_DIR           = 'environments/prod'
        TF_IN_AUTOMATION = 'true'
        S3_BUCKET        = 'e-commerce-artifactory'
        PROJECT_TAG      = 'task-stats-microservices'
        ENV_TAG          = 'prod'
    }

    stages {
        // ---------------------------------------------------------------------
        // Stage 1: Pre-Flight & Identity Verification
        // ---------------------------------------------------------------------
        stage('Pre-Flight & Identity Check') {
            steps {
                script {
                    echo "=========================================================="
                    echo " Stage 1: Validating Environment & AWS Identity          "
                    echo " Target Action : ${params.ACTION.toUpperCase()}           "
                    echo " AWS Region    : ${AWS_REGION}                           "
                    echo " Root Directory: ${TF_DIR}                               "
                    echo " S3 State Store: ${S3_BUCKET}                            "
                    echo "=========================================================="

                    // Verify Terraform Version >= 1.10.0 (required for native S3 locking)
                    sh '''
                        echo "[INFO] Checking Terraform CLI version..."
                        terraform -version

                        TF_RAW_VER=$(terraform -version -json 2>/dev/null | grep -o '"terraform_version": *"[^"]*"' | cut -d'"' -f4 || terraform -version | head -n1 | grep -o '[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+')
                        echo "[INFO] Detected Terraform Version: ${TF_RAW_VER}"

                        python3 -c "
import sys
v = sys.argv[1].split('.')
major, minor = int(v[0]), int(v[1])
if not (major > 1 or (major == 1 and minor >= 10)):
    sys.exit(1)
" "${TF_RAW_VER}" 2>/dev/null || python -c "
import sys
v = sys.argv[1].split('.')
major, minor = int(v[0]), int(v[1])
if not (major > 1 or (major == 1 and minor >= 10)):
    sys.exit(1)
" "${TF_RAW_VER}" || {
                            echo "[ERROR] Terraform >= 1.10.0 is strictly required for native S3 state locking."
                            exit 1
                        }
                    '''

                    // Verify AWS IAM Role / Instance Profile Identity
                    sh """
                        echo "[INFO] Verifying IAM Instance Profile identity via AWS STS..."
                        aws sts get-caller-identity --region ${AWS_REGION}

                        echo "[INFO] Verifying accessibility of S3 state storage bucket..."
                        aws s3 ls s3://${S3_BUCKET}/ --region ${AWS_REGION} > /dev/null
                        echo "[SUCCESS] S3 bucket s3://${S3_BUCKET}/ is accessible."
                    """
                }
            }
        }

        // ---------------------------------------------------------------------
        // Stage 2: Terraform Format, Init & Validate
        // ---------------------------------------------------------------------
        stage('Terraform Format, Init & Validate') {
            steps {
                script {
                    echo "Verifying canonical code formatting across all modules..."
                    sh "terraform fmt -check -recursive"

                    echo "Initializing Terraform working directory..."
                    dir("${TF_DIR}") {
                        sh """
                            terraform init -input=false -no-color
                            terraform validate -no-color
                        """
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Stage 3: Terraform Plan Generation
        // ---------------------------------------------------------------------
        stage('Terraform Plan') {
            steps {
                script {
                    dir("${TF_DIR}") {
                        if (params.ACTION == 'destroy') {
                            echo "Generating speculative DESTROY plan..."
                            sh "terraform plan -destroy -out=tfplan -input=false -no-color"
                        } else {
                            echo "Generating speculative PROVISIONING plan..."
                            sh "terraform plan -out=tfplan -input=false -no-color"
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Stage 4: Manual Approval Gate (For Apply & Destroy)
        // ---------------------------------------------------------------------
        stage('Manual Approval Gate') {
            when {
                expression {
                    return params.ACTION == 'apply' || params.ACTION == 'destroy'
                }
            }
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: "Review the Terraform plan above. Approve ${params.ACTION.toUpperCase()} for PROD?",
                          ok: "Proceed with ${params.ACTION.toUpperCase()}"
                }
            }
        }

        // ---------------------------------------------------------------------
        // Stage 5: Terraform Apply / Destroy Execution
        // ---------------------------------------------------------------------
        stage('Terraform Apply / Destroy') {
            when {
                expression {
                    return params.ACTION == 'apply' || params.ACTION == 'destroy'
                }
            }
            steps {
                script {
                    dir("${TF_DIR}") {
                        echo "Executing exact validated plan artifact (action: ${params.ACTION.toUpperCase()})..."
                        sh "terraform apply -input=false -no-color tfplan"
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // Stage 6: Post-Apply Exit Gate (AWS SSM Agent & Parameter Verification)
        // ---------------------------------------------------------------------
        stage('Post-Apply Exit Gate') {
            when {
                expression {
                    return params.ACTION == 'apply'
                }
            }
            steps {
                script {
                    echo "=========================================================="
                    echo " Stage 6: Polling EC2 Instances & AWS SSM Readiness       "
                    echo " Target: 3 Instances (1 Master + 2 Workers)               "
                    echo " Maximum Wait: 5 Minutes (Polling every 15s)              "
                    echo "=========================================================="

                    sh """
                        set -e
                        TARGET_COUNT=3
                        MAX_RETRIES=20
                        RETRY_INTERVAL=15

                        echo "[INFO] Discovering running EC2 instances for Project: ${PROJECT_TAG}..."
                        INSTANCE_IDS=\$(aws ec2 describe-instances \
                            --filters "Name=tag:Project,Values=${PROJECT_TAG}" \
                                      "Name=tag:Environment,Values=${ENV_TAG}" \
                                      "Name=instance-state-name,Values=running" \
                            --query "Reservations[].Instances[].InstanceId" \
                            --output text \
                            --region ${AWS_REGION})

                        DISCOVERED_COUNT=\$(echo "\$INSTANCE_IDS" | wc -w)
                        echo "[INFO] Discovered \$DISCOVERED_COUNT running instance(s): \$INSTANCE_IDS"

                        if [ "\$DISCOVERED_COUNT" -ne "\$TARGET_COUNT" ]; then
                            echo "[ERROR] Expected \$TARGET_COUNT running instances, found \$DISCOVERED_COUNT."
                            exit 1
                        fi

                        echo "[INFO] Polling AWS Systems Manager (SSM) for Online agent heartbeat..."
                        ONLINE_COUNT=0
                        for i in \$(seq 1 \$MAX_RETRIES); do
                            ONLINE_IDS=\$(aws ssm describe-instance-information \
                                --filters "Key=PingStatus,Values=Online" \
                                --query "InstanceInformationList[].InstanceId" \
                                --output text \
                                --region ${AWS_REGION})

                            MATCHED=0
                            for inst in \$INSTANCE_IDS; do
                                if echo "\$ONLINE_IDS" | grep -qw "\$inst"; then
                                    MATCHED=\$((MATCHED + 1))
                                fi
                            done

                            echo "  [Attempt \$i/\$MAX_RETRIES] \$MATCHED of \$TARGET_COUNT nodes Online in SSM..."
                            if [ "\$MATCHED" -eq "\$TARGET_COUNT" ]; then
                                echo "[SUCCESS] All \$TARGET_COUNT nodes successfully registered and Online in SSM!"
                                ONLINE_COUNT=\$MATCHED
                                break
                            fi
                            sleep \$RETRY_INTERVAL
                        done

                        if [ "\$ONLINE_COUNT" -ne "\$TARGET_COUNT" ]; then
                            echo "[ERROR] Timed out waiting for all \$TARGET_COUNT instances to report Online in SSM."
                            exit 1
                        fi

                        echo "[INFO] Verifying Stage 2 / Stage 3 SSM Handoff Parameters..."
                        ALB_DNS=\$(aws ssm get-parameter --name "/prod/app/alb_dns" --query "Parameter.Value" --output text --region ${AWS_REGION})
                        RDS_ENDPOINT=\$(aws ssm get-parameter --name "/prod/app/rds_endpoint" --query "Parameter.Value" --output text --region ${AWS_REGION})
                        ECR_TASK=\$(aws ssm get-parameter --name "/prod/app/ecr_task_repo_url" --query "Parameter.Value" --output text --region ${AWS_REGION})
                        ECR_STATS=\$(aws ssm get-parameter --name "/prod/app/ecr_stats_repo_url" --query "Parameter.Value" --output text --region ${AWS_REGION})
                        MASTER_IP=\$(aws ssm get-parameter --name "/prod/k8s/master_private_ip" --query "Parameter.Value" --output text --region ${AWS_REGION})

                        echo "=========================================================="
                        echo " Stage 1 Infrastructure Handoff Verified:                 "
                        echo " - Public ALB DNS  : \$ALB_DNS                              "
                        echo " - RDS Endpoint    : \$RDS_ENDPOINT                         "
                        echo " - Master Node IP  : \$MASTER_IP                            "
                        echo " - Task ECR Repo   : \$ECR_TASK                             "
                        echo " - Stats ECR Repo  : \$ECR_STATS                            "
                        echo "=========================================================="
                    """
                }
            }
        }

        // ---------------------------------------------------------------------
        // Stage 7: Post-Destroy Billing Verification
        // ---------------------------------------------------------------------
        stage('Post-Destroy Billing Verification') {
            when {
                expression {
                    return params.ACTION == 'destroy'
                }
            }
            steps {
                script {
                    echo "=========================================================="
                    echo " Stage 7: Verifying Complete Teardown of Billable AWS Core "
                    echo " Checking NAT Gateways, ALBs, and RDS Instances...        "
                    echo "=========================================================="

                    sh """
                        echo "[INFO] Checking for active NAT Gateways..."
                        NAT_COUNT=\$(aws ec2 describe-nat-gateways \
                            --filter "Name=tag:Project,Values=${PROJECT_TAG}" "Name=state,Values=available,pending" \
                            --query "NatGateways[].NatGatewayId" \
                            --output text \
                            --region ${AWS_REGION} | wc -w)
                        echo "Active NAT Gateways remaining: \$NAT_COUNT"

                        echo "[INFO] Checking for active Application Load Balancers..."
                        ALB_EXISTS=\$(aws elbv2 describe-load-balancers \
                            --names "alb-${ENV_TAG}" \
                            --region ${AWS_REGION} 2>/dev/null | grep -o '"LoadBalancerArn"' | wc -l || true)
                        echo "ALB instances remaining: \$ALB_EXISTS"

                        echo "[INFO] Checking for active RDS PostgreSQL instances..."
                        RDS_EXISTS=\$(aws rds describe-db-instances \
                            --db-instance-identifier "rds-${ENV_TAG}-postgres" \
                            --region ${AWS_REGION} 2>/dev/null | grep -o '"DBInstanceIdentifier"' | wc -l || true)
                        echo "RDS instances remaining: \$RDS_EXISTS"

                        if [ "\$NAT_COUNT" -eq 0 ] && [ "\$ALB_EXISTS" -eq 0 ] && [ "\$RDS_EXISTS" -eq 0 ]; then
                            echo "[SUCCESS] Zero billable compute/network resources remain for ${PROJECT_TAG}."
                        else
                            echo "[WARNING] Some resources may still be terminating asynchronously."
                        fi
                    """
                }
            }
        }
    }

    post {
        always {
            script {
                echo "[CLEANUP] Pruning speculative binary plan artifact from workspace..."
                sh "rm -f ${TF_DIR}/tfplan"
            }
        }
    }
}
