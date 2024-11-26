resource "aws_security_group" "redis" {
  name        = "gitlab-redis-sec-group"
  description = "Security group for GitLab Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [
      aws_security_group.gitlab_lb.id,  # Allow from the load balancer security group
      aws_security_group.bastion.id    # Allow from the Bastion security group
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "gitlab-redis-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.name_tag}-redis-subnet-group"
  }
}

resource "aws_elasticache_replication_group" "gitlab_redis" {
  replication_group_id          = "gitlab-redis"
  description = "Redis cluster for GitLab"
  node_type                     = "cache.t3.medium"
  num_cache_clusters         = 3
  automatic_failover_enabled    = true
  engine                        = "redis"
  engine_version                = "6.x"
  port                          = 6379
  subnet_group_name             = aws_elasticache_subnet_group.redis.name
  security_group_ids            = [aws_security_group.redis.id]

  preferred_cache_cluster_azs = [
    data.aws_availability_zones.available.names[0],
    data.aws_availability_zones.available.names[1],
    data.aws_availability_zones.available.names[2]
  ]

  tags = {
    Name = "gitlab-redis-cluster"
  }
}
