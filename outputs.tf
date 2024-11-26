output "rds_endpoint" {
  value = aws_db_instance.gitlab.endpoint
  description = "The RDS endpoint"
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.gitlab_redis.primary_endpoint_address
  description = "The primary endpoint of the GitLab Redis replication group."
}

output "gitlab_db_password" {
  value = random_string.gitlab_db_password.result
  description = "GitLab Database Password"
  sensitive = true  # This marks the output as sensitive in Terraform
}