# Routie Terraform Infrastructure

> AWS 인프라를 Terraform으로 관리하는 Routie 프로젝트의 IaC(Infrastructure as Code) 저장소입니다.

## 📖 문서

전체 인프라 구성 및 배포 가이드는 **[INFRASTRUCTURE_GUIDE.md](./INFRASTRUCTURE_GUIDE.md)** 문서를 참고하세요.

## 🏗️ 인프라 구조

```
Backend: EC2 (Spring Boot) + VPC + CloudWatch
Frontend: S3 + CloudFront + ACM (HTTPS)
```

## 📂 프로젝트 구조

```
terraform/
├── backend/                    # 백엔드 인프라 (EC2, VPC)
│   ├── bootstrap/             # Terraform State용 S3 초기 설정
│   ├── environments/dev/      # 개발 환경 배포 설정
│       ├── compute/          # SSH 키페어, S3
│       ├── iam/              # IAM 역할, CloudWatch 설정
│       ├── compute/          # SSH 키페어, S3
│       ├── iam/              # IAM 역할, CloudWatch 설정
    ├── environments/dev/     # 개발 환경 배포 설정
# Prod 환경 키 다운로드
    ├── environments/dev/     # 개발 환경 배포 설정
cd terraform/frontend/bootstrap
    ├── environments/dev/     # 개발 환경 배포 설정
terraform init
terraform plan
terraform apply

배포되는 리소스:
#### Dev 환경

- CloudFront Distribution (CDN)
terraform apply
```


# Frontend State 버킷
cd terraform/frontend/bootstrap
배포되는 리소스:
```bash
# 검증 레코드 확인
terraform output acm_validation_records
```

## 📊 주요 리소스
```bash
#### Dev 환경
- **VPC**: 10.0.0.0/16
terraform apply
```
- **EC2**: Ubuntu 24.04 ARM64, t4g.small, 20GB gp3 EBS
배포되는 리소스:
### Frontend
- **S3**: Private bucket with versioning, encryption
- **CloudFront**: HTTPS only, Global CDN
- **ACM**: TLS 1.2+ certificate
- **OAC**: S3 직접 접근 차단
## 📈 모니터링
```bash
### CloudWatch Logs
- `/aws/ec2/routie/nginx/access` - Nginx 접근 로그
## 📈 모니터링

### CloudWatch Logs
- `/aws/ec2/routie/application` - Spring Boot 로그
- `/aws/ec2/routie/exception` - 예외 로그 (JSON)
ssh -i ~/.ssh/routie-prod-private-key.pem ubuntu@<PROD_ELASTIC_IP>
- `/aws/ec2/routie/request` - HTTP 요청 로그 (JSON)

### CloudWatch Metrics (Namespace: Routie/EC2)
**로그 그룹**: `/routie/{environment}` (dev 또는 prod)
```bash
**로그 스트림** (인스턴스별):
- `{instance_id}/log` - Spring Boot 애플리케이션 로그
- `{instance_id}/exception` - 예외 로그 (JSON)
- `{instance_id}/request` - HTTP 요청 로그 (JSON)
- `{instance_id}/health` - 헬스체크 로그

### CloudWatch Metrics
**Namespace**: `Routie/Dev` 또는 `Routie/Prod`

**수집 메트릭**:
- CPU: 사용률, idle, user, system
- Memory: 사용률 (%)
- Disk: 디스크 사용률 (/)
- Network: In/Out

```

# EC2 접속
ssh -i key.pem ubuntu@<ELASTIC_IP>
aws logs tail /routie/dev --follow

# 특정 스트림 확인
aws logs tail /routie/dev --follow --filter-pattern '{instance_id}/log'
# Docker로 배포
cd /home/ubuntu/app
docker-compose pull
docker-compose up -d

# 로그 확인
docker-compose logs -f
```

### Frontend 배포

```bash
# 빌드
npm run build

# S3 업로드
aws s3 sync ./build/ s3://routie-frontend-dev/ --delete

# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

## 💰 예상 비용 (월간, dev 환경)
# EC2 접속 (환경별 키 사용)
# Dev 환경
ssh -i ~/.ssh/routie-dev-private-key.pem ubuntu@<DEV_ELASTIC_IP>

# Prod 환경
ssh -i ~/.ssh/routie-prod-private-key.pem ubuntu@<PROD_ELASTIC_IP>
- EC2 t4g.small: ~$13
- EBS 20GB gp3: ~$2
- CloudWatch Logs: ~$1

### Frontend
- S3 Storage (10GB): ~$0.5
- CloudFront: ~$1-3 (트래픽에 따라)

# CloudWatch 로그도 함께 모니터링
aws logs tail /routie/dev --follow  # dev 환경
aws logs tail /routie/prod --follow  # prod 환경