aws_region               = "ap-southeast-2"
environment              = "prod"
vpc_cidr                 = "10.0.0.0/16"
availability_zones       = ["ap-southeast-2a", "ap-southeast-2b"]
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
isolated_db_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
single_nat_gateway       = true

instance_type        = "t3.small"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name              = "taskdb"
db_master_username   = "dbadmin"
skip_final_snapshot  = true
