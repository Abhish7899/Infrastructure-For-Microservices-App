terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_YOUR_TFSTATE_BUCKET"
    key          = "microservices/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
    encrypt      = true
  }
}
