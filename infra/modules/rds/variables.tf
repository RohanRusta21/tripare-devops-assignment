variable "name" {
  description = "Name prefix (e.g. hotel-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the DB subnet group (at least two AZs)."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "RDS subnet groups need subnets in at least two AZs."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach the database (the ECS tasks SG)."
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.4"
}

variable "engine_version_major" {
  description = "Major version used for the parameter group family."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB (0 disables)."
  type        = number
  default     = 100
}

variable "kms_key_id" {
  description = "KMS key ARN for storage encryption. null = AWS-managed aws/rds key."
  type        = string
  default     = null
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "hotel"
}

variable "master_username" {
  description = "Master username. Password is managed by RDS in Secrets Manager."
  type        = string
  default     = "hotel_admin"
}

variable "port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "multi_az" {
  description = "Deploy a standby in a second AZ."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Automated backup retention (0-35 days)."
  type        = number

  validation {
    condition     = var.backup_retention_days >= 0 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 0 and 35."
  }
}

variable "backup_window" {
  description = "Daily backup window (UTC)."
  type        = string
  default     = "20:00-21:00" # ~01:30 IST, low traffic
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)."
  type        = string
  default     = "sun:21:30-sun:22:30"
}

variable "deletion_protection" {
  description = "Prevent the instance from being deleted."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. Should be false in prod."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 disables)."
  type        = number
  default     = 0
}

variable "slow_query_threshold_ms" {
  description = "log_min_duration_statement value."
  type        = number
  default     = 1000
}

variable "apply_immediately" {
  description = "Apply modifications immediately instead of in the maintenance window."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
