resource "aws_vpc" "vpc" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = false
  enable_dns_support               = true
  enable_dns_hostnames             = true
  instance_tenancy                 = "default"

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_subnet" "public_a" {
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = "10.0.0.0/24"
  assign_ipv6_address_on_creation = false
  availability_zone               = "${var.region}a"
  map_public_ip_on_launch         = false

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-public-a"
  })
}

resource "aws_subnet" "private_a" {
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = "10.0.10.0/24"
  assign_ipv6_address_on_creation = false
  availability_zone               = "${var.region}a"
  map_public_ip_on_launch         = false

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-private-a"
  })
}

resource "aws_subnet" "public_b" {
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = "10.0.1.0/24"
  assign_ipv6_address_on_creation = false
  availability_zone               = "${var.region}b"
  map_public_ip_on_launch         = false

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-public-b"
  })
}

resource "aws_subnet" "private_b" {
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = "10.0.11.0/24"
  assign_ipv6_address_on_creation = false
  availability_zone               = "${var.region}b"
  map_public_ip_on_launch         = false

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-private-b"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public_rt_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}
