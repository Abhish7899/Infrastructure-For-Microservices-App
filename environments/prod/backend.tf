# Remote state stored in S3 with native S3 locking (Terraform >= 1.10.0)
terraform {
  backend "s3" {
    bucket       = "e-commerce-artifactory"
    key          = "microservices/prod/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
