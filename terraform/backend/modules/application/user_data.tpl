#!/bin/bash
apt-get update -y

# Docker 설치
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
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
