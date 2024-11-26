# Create a security group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.name_tag}-rds-sec-group"
  description = "Security group for GitLab RDS"
  vpc_id      = aws_vpc.main.id  

  ingress {
    from_port   = 5432  # Default port for PostgreSQL
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Adjust to only allow trusted IPs for better security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_tag}-rds-sec-group"
  }
}

# Create db subnet group
resource "aws_db_subnet_group" "private" {
  name       = "${var.name_tag}-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

# Create random id for GitLab db password
resource "random_string" "gitlab_db_password" {
  length           = 10
  special          = true
  override_special = "!#$%&*+-.?^_{|}~"  # Use only AWS-compliant characters
}

# Create GitLab RDS
resource "aws_db_instance" "gitlab" {
  identifier             = "${var.name_tag}-db"
  engine                 = "postgres"
  instance_class         = "db.m5.large"
  allocated_storage      = 100
  multi_az               = true
  username               = "gitlab"
  password               = "${random_string.gitlab_db_password.result}"
  db_name                = var.gitlab_db_name
  db_subnet_group_name   = "${aws_db_subnet_group.private.id}"
  vpc_security_group_ids = ["${aws_security_group.rds.id}"]
  skip_final_snapshot    = true
}

