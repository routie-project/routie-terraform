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

# CloudWatch Logs 그룹 생성
resource "aws_cloudwatch_log_group" "syslog" {
  name              = "/aws/ec2/routie/syslog"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/aws/ec2/routie/nginx/access"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "/aws/ec2/routie/nginx/error"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "routie_application" {
  name              = "/aws/ec2/routie/application"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "routie_exception" {
  name              = "/aws/ec2/routie/exception"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "routie_request" {
  name              = "/aws/ec2/routie/request"
  retention_in_days = 7
}

