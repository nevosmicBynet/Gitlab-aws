# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_tag}-vpc"
  }
}

# Get the list of available availability zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
}


# Create subnets
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 3) # Added offset to avoid conflicts
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name_tag}-subnet-private-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name_tag}-subnet-public-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# Create Elastic IPs for NAT Gateway
resource "aws_eip" "nat" {
  count = length(aws_subnet.public)
  domain = "vpc"

  tags = {
    Name = "${var.name_tag}-eip-nat-${count.index}"
  }
}

# Create NAT gateways
resource "aws_nat_gateway" "main" {
  count         = length(aws_subnet.public)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name_tag}-ng-${aws_subnet.public[count.index].availability_zone}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_tag}-ig"
  }
}

# Create route tables
resource "aws_route_table" "private" {
  count  = length(aws_subnet.private)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_tag}-rt-private-${aws_subnet.private[count.index].availability_zone}"
  }
}

# Create routes for NAT Gateway
resource "aws_route" "nat_gateway" {
  count                  = length(aws_nat_gateway.main) #length(aws_route_table.private)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# Create route table associations
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}

# Create route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_tag}-rt-public"
  }
}

# Create route for Internet Gateway
resource "aws_route" "internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Create route table associations for public subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}