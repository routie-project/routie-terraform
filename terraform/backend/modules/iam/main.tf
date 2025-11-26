resource "aws_iam_role" "ec2_cw_role" {
  name = "ec2_cloudwatch_agent_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_agent_policy_attach" {
  role       = aws_iam_role.ec2_cw_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  role       = aws_iam_role.ec2_cw_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_cw_profile" {
  name = "ec2_cloudwatch_profile"
  role = aws_iam_role.ec2_cw_role.name
}

resource "aws_cloudwatch_log_group" "routie_main" {
  name              = "/routie/${var.environment}"
  retention_in_days = 7
}

