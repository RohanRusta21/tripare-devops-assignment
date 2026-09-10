environment = "dev"
region      = "ap-south-1"

vpc_cidr           = "10.10.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
single_nat_gateway = true

task_cpu           = 256
task_memory        = 512
desired_count      = 1
use_fargate_spot   = true
container_insights = false
log_retention_days = 7

rds_instance_class               = "db.t4g.micro"
rds_allocated_storage            = 20
rds_max_allocated_storage        = 50
rds_multi_az                     = false
rds_backup_retention_days        = 1
rds_skip_final_snapshot          = true
rds_performance_insights_enabled = false
rds_monitoring_interval          = 0
rds_apply_immediately            = true

deletion_protection = false
