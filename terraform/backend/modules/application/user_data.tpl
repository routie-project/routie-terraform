#!/bin/bash
apt-get update -y

# Docker 설치
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Nginx 설치
apt-get install -y nginx

# Swapfile 4GiB 생성
fallocate -l 4GiB /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Swapfile 재부팅 후에도 유지
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab

# CloudWatch Agent 설치
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm ./amazon-cloudwatch-agent.deb

# CloudWatch Agent 설정 파일 생성
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "Routie/${environment_title}",
    "append_dimensions": {
      "InstanceId": "\$${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MemoryUtilization",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DiskSpaceUtilization",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/home/ubuntu/logs/routie.log",
            "log_group_name": "/routie/${environment}",
            "log_stream_name": "{instance_id}/log",
            "timezone": "Local"
          },
          {
            "file_path": "/home/ubuntu/logs/routie-exception.json",
            "log_group_name": "/routie/${environment}",
            "log_stream_name": "{instance_id}/exception",
            "timezone": "Local"
          },
          {
            "file_path": "/home/ubuntu/logs/routie-request.json",
            "log_group_name": "/routie/${environment}",
            "log_stream_name": "{instance_id}/request",
            "timezone": "Local"
          },
          {
            "file_path": "/home/ubuntu/logs/routie-health.log",
            "log_group_name": "/routie/${environment}",
            "log_stream_name": "{instance_id}/health",
            "timezone": "Local"
          }
        ]
      }
    }
  },
  "telemetry": {
    "logs": {
      "level": "info"
    }
  }
}
EOF

# CloudWatch Agent 시작
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

