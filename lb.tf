# Create Load Balancer
resource "aws_lb" "gitlab" {
  name               = "gitlab-loadbalancer"
  internal           = false
  load_balancer_type = "network"
  ip_address_type    = "ipv4"
  subnets            = [aws_subnet.public[0].id, aws_subnet.public[1].id]  # Use public subnets
  security_groups    = [aws_security_group.gitlab_lb.id]  # Security Group for NLB

  enable_deletion_protection = false
}

# Create security group for Load Balancer
resource "aws_security_group" "gitlab_lb" {
  name        = "gitlab-loadbalancer-sec-group"
  description = "Security group for GitLab load balancer"
  vpc_id      = aws_vpc.main.id 

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Modify based on trusted IPs for SSH
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Target Group for HTTP (Port 80)
resource "aws_lb_target_group" "http" {
  name     = "gitlab-loadbalancer-http-target"
  protocol = "TCP"
  port     = 80
  vpc_id   = aws_vpc.main.id
  target_type = "instance"  # Using EC2 instances as target

  health_check {
    protocol = "HTTP"
    path     = "/readiness"  # Health check endpoint
    interval = 30
    timeout  = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create Target Group for SSH (Port 22)
resource "aws_lb_target_group" "ssh" {
  name     = "gitlab-loadbalancer-ssh-target"
  protocol = "TCP"
  port     = 22
  vpc_id   = aws_vpc.main.id
  target_type = "instance"  # Using EC2 instances as target

  health_check {
    protocol = "TCP"  # TCP health check for SSH
    interval = 30
    timeout  = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create Target Group for HTTPS (Port 443)
resource "aws_lb_target_group" "https" {
  name     = "gitlab-loadbalancer-https-target"
  protocol = "TCP"
  port     = 443
  vpc_id   = aws_vpc.main.id
  target_type = "instance"  # Using EC2 instances as target

  health_check {
    protocol = "HTTP"
    path     = "/readiness"  # Health check endpoint
    interval = 30
    timeout  = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create Listener for Port 22 (SSH)
resource "aws_lb_listener" "ssh" {
  load_balancer_arn = aws_lb.gitlab.arn
  port              = 22
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ssh.arn
  }
}

# Create Listener for Port 80 (HTTP)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.gitlab.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

# Create Listener for Port 443 (HTTPS)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.gitlab.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

# Attach the Bastion Host to the HTTP Target Group
# This enables HTTP traffic (Port 80) to be forwarded to the Bastion Host instance
resource "aws_lb_target_group_attachment" "bastion_http" {
  target_group_arn = aws_lb_target_group.http.arn  # Reference the HTTP Target Group
  target_id        = aws_instance.bastion_a.id    # Target the Bastion Host instance
  port             = 80                           # Forward traffic on Port 80
}

# Attach the Bastion Host to the HTTPS Target Group
# This enables HTTPS traffic (Port 443) to be forwarded to the Bastion Host instance
resource "aws_lb_target_group_attachment" "bastion_https" {
  target_group_arn = aws_lb_target_group.https.arn # Reference the HTTPS Target Group
  target_id        = aws_instance.bastion_a.id     # Target the Bastion Host instance
  port             = 443                           # Forward traffic on Port 443
}

# Attach the Bastion Host to the SSH Target Group
# This enables SSH traffic (Port 22) to be forwarded to the Bastion Host instance
resource "aws_lb_target_group_attachment" "bastion_ssh" {
  target_group_arn = aws_lb_target_group.ssh.arn   # Reference the SSH Target Group
  target_id        = aws_instance.bastion_a.id     # Target the Bastion Host instance
  port             = 22                            # Forward traffic on Port 22
}

