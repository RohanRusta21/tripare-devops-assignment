variable "name" {
  description = "Name prefix (e.g. hotel-dev)."
  type        = string
}

variable "region" {
  description = "AWS region (used for the awslogs driver)."
  type        = string
}

variable "vpc_id" {
  description = "VPC to deploy into."
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets for the ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Subnets for the Fargate tasks."
  type        = list(string)
}

variable "container_image" {
  description = "Image for the placeholder app."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:1.27-alpine"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "ALB health check path."
  type        = string
  default     = "/"
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of tasks to run."
  type        = number
  default     = 1
}

variable "use_fargate_spot" {
  description = "Run on FARGATE_SPOT (cheap, interruptible - dev only)."
  type        = bool
  default     = false
}

variable "container_insights" {
  description = "Enable CloudWatch Container Insights on the cluster."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 14
}

variable "deletion_protection" {
  description = "Protect the ALB from accidental deletion."
  type        = bool
  default     = false
}

variable "db_host" {
  description = "RDS endpoint address passed to the container as DB_HOST."
  type        = string
  default     = ""
}

variable "db_port" {
  description = "RDS port passed as DB_PORT."
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name passed as DB_NAME."
  type        = string
  default     = ""
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN holding DB credentials (RDS managed master password). Injected as a secret, never as plain env."
  type        = string
  default     = null
}

variable "extra_environment" {
  description = "Additional non-secret environment variables for the container."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}