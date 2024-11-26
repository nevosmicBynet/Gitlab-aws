# Create Bastion Security Group
resource "aws_security_group" "bastion" {
  name        = "bastion-sec-group"
  description = "Security group for Bastion Hosts"
  vpc_id      = aws_vpc.main.id

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Adjust to restrict SSH access
  }

  # Allow HTTP traffic from the GitLab Load Balancer security group
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.gitlab_lb.id]
  }

#  # Allow HTTPS traffic from the GitLab Load Balancer security group
#  ingress {
#    from_port   = 443
#    to_port     = 443
#    protocol    = "tcp"
#    cidr_blocks = [aws_security_group.gitlab_lb.id]
#  }

  # Outbound rules (egress)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Specific HTTP outbound rule to the load balancer
  egress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.gitlab_lb.id]
  }

  # Specific HTTPS outbound rule to the load balancer
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.gitlab_lb.id]
  }

  tags = {
    Name = "${var.name_tag}-bastion-sec-group"
  }
}

# Create Bastion Host A
resource "aws_instance" "bastion_a" {
  ami                         = var.linux_ami_id
  instance_type               = "c5.2xlarge"
  subnet_id                   = aws_subnet.public[0].id
  key_name                    = aws_key_pair.bastion_a.key_name
  associate_public_ip_address = true  # Elastic IP will be assigned separately

  # Correctly reference the IAM instance profile
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile_for_script.name

user_data = <<-EOT
    #!/bin/bash
    # Update packages
    sudo yum update -y
    
    # Install any dependencies your script needs
    sudo yum install -y curl wget

    # Extract host part of the RDS endpoint
    rds_host=$(echo "${aws_db_instance.gitlab.endpoint}" | cut -d':' -f1)

    # Get the script from bucket
    aws s3 cp s3://gitlab-nimbus-michal/install-gitlab.sh /tmp/install-gitlab.sh
    chmod +x /tmp/install-gitlab.sh
      # Run the installation script with the necessary parameters
    sudo /tmp/install-gitlab.sh \
      "$rds_host" \
      "${aws_elasticache_replication_group.gitlab_redis.primary_endpoint_address}" \
      "${var.lb_dns_name}" \
      "${var.gitlab_db_name}" \
      "${random_string.gitlab_db_password.result}" >> install_gitlab.log 2>&1
  EOT

  tags = {
    Name = "${var.name_tag}-bastion"
  }

  security_groups = [aws_security_group.bastion.id]
}

# Create key pairs for SSH
resource "aws_key_pair" "bastion_a" {
  key_name   = "bastion-host-a"
  public_key = file("~/.ssh/bastion-host-a.pub") 
}

# Elastic IPs for Bastion Hosts
resource "aws_eip" "bastion_a_eip" {
  instance = aws_instance.bastion_a.id
  domain   = "vpc"
}

## Create Bastion Host B
#resource "aws_instance" "bastion_b" {
#  ami                         = var.linux_ami_id
#  instance_type               = "c5.2xlarge"
#  subnet_id                   = aws_subnet.public[1].id
#  key_name                    = aws_key_pair.bastion_b.key_name
#  associate_public_ip_address = false  # Elastic IP will be assigned separately
#
#  tags = {
#    Name = "${var.name_tag} Bastion Host B"
#  }
#
#  security_groups = [aws_security_group.bastion.id]
#}

#resource "aws_key_pair" "bastion_b" {
#  key_name   = "bastion-host-b"
#  public_key = file("~/.ssh/bastion-host-b.pub")
#}

#resource "aws_eip" "bastion_b_eip" {
#  instance = aws_instance.bastion_b.id
#  domain   = "vpc"
#}


