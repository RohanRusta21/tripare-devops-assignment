environment = "prod"
region      = "ap-south-1"

vpc_cidr           = "10.20.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
single_nat_gateway = false

task_cpu           = 1024
task_memory        = 2048
desired_count      = 3
use_fargate_spot   = false
container_insights = true
log_retention_days = 90

rds_instance_class               = "db.m6g.large"
rds_allocated_storage            = 100
rds_max_allocated_storage        = 500
rds_multi_az                     = true
rds_backup_retention_days        = 30
rds_skip_final_snapshot          = false
rds_performance_insights_enabled = true
rds_monitoring_interval          = 60
rds_apply_immediately            = false

deletion_protection = true
