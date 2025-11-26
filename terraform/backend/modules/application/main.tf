data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
}

resource "aws_security_group" "app_sg" {
  name   = "${var.project_name}-${var.environment}-ec2-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH traffic"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-ec2-sg"
  })
}

resource "aws_instance" "app_instance" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  key_name = var.key_pair_name

  # CloudWatch Agent를 위한 IAM Instance Profile 연결
  iam_instance_profile = var.iam_instance_profile_name

  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = templatefile("${path.module}/user_data.tpl", {
    environment       = var.environment
    environment_title = title(var.environment)
  })

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-${var.environment}-app"
  })
}

resource "aws_eip" "app_eip" {
  domain = "vpc"

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-${var.environment}-app-eip"
  })
}

resource "aws_eip_association" "app_eip_association" {
  instance_id   = aws_instance.app_instance.id
  allocation_id = aws_eip.app_eip.id
}
