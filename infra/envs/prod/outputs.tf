output "alb_dns_name" {
  description = "Public URL of the app."
  value       = "http://${module.ecs.alb_dns_name}"
}

output "rds_endpoint" {
  description = "Private RDS endpoint (only reachable from ECS)."
  value       = module.rds.endpoint
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN for the DB master credentials."
  value       = module.rds.master_user_secret_arn
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}
