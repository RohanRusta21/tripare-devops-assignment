variable "project" {
  description = "Project name, used as a prefix on every resource."
  type        = string
  default     = "hotel"
}

variable "environment" {
  description = "Environment name (dev, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "plan_only" {
  description = "Skip AWS credential/API validation so plan works without an account."
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
}

variable "availability_zones" {
  description = "AZs to use (2+)."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "One NAT for all AZs (dev) vs one per AZ (prod)."
  type        = bool
}

variable "container_image" {
  description = "Application image."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:1.27-alpine"
}

variable "container_port" {
  description = "Container port."
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate CPU units."
  type        = number
}

variable "task_memory" {
  description = "Fargate memory (MiB)."
  type        = number
}

variable "desired_count" {
  description = "Number of running tasks."
  type        = number
}

variable "use_fargate_spot" {
  description = "Use FARGATE_SPOT capacity."
  type        = bool
  default     = false
}

variable "container_insights" {
  description = "Enable Container Insights."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 14
}

variable "rds_engine_version" {
  description = "PostgreSQL version."
  type        = string
  default     = "16.4"
}

variable "rds_engine_version_major" {
  description = "PostgreSQL major version (parameter group family)."
  type        = string
  default     = "16"
}

variable "rds_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "rds_allocated_storage" {
  description = "Initial storage (GiB)."
  type        = number
}

variable "rds_max_allocated_storage" {
  description = "Autoscaling storage ceiling (GiB)."
  type        = number
}

variable "rds_multi_az" {
  description = "Multi-AZ standby."
  type        = bool
}

variable "rds_backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on destroy."
  type        = bool
}

variable "rds_performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = false
}

variable "rds_monitoring_interval" {
  description = "Enhanced monitoring interval (seconds, 0 = off)."
  type        = number
  default     = 0
}

variable "rds_apply_immediately" {
  description = "Apply RDS changes immediately."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Deletion protection for RDS and the ALB."
  type        = bool
}
