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
│   └── modules/               # 재사용 가능한 모듈
│       ├── application/       # EC2 애플리케이션 서버
│       ├── compute/          # SSH 키페어, S3
│       ├── iam/              # IAM 역할, CloudWatch 설정
│       └── network/          # VPC, 서브넷, 라우팅
│
└── frontend/                  # 프론트엔드 인프라 (S3, CloudFront)
    ├── bootstrap/            # Terraform State용 S3 초기 설정
    ├── environments/dev/     # 개발 환경 배포 설정
    └── modules/static-website/  # S3 + CloudFront 정적 웹사이트
```

## 🚀 빠른 시작

### 1. 사전 준비

```bash
# AWS CLI 설정
aws configure

# Terraform 설치 (macOS)
brew install terraform
```

### 2. Bootstrap (최초 1회)

Terraform State를 저장할 S3 버킷을 생성합니다.

```bash
# Backend State 버킷
cd terraform/backend/bootstrap
terraform init && terraform apply

# Frontend State 버킷
cd terraform/frontend/bootstrap
terraform init && terraform apply
```

### 3. Backend 인프라 배포

```bash
cd terraform/backend/environments/dev
terraform init
terraform plan
terraform apply
```

배포되는 리소스:
- VPC, 서브넷 (Public/Private)
- EC2 인스턴스 (Ubuntu 24.04, t4g.small)
- 보안그룹, Elastic IP
- CloudWatch Agent (자동 설치)
- IAM 역할, CloudWatch Log Groups

### 4. Frontend 인프라 배포

```bash
cd terraform/frontend/environments/dev
terraform init
terraform plan
terraform apply
```

배포되는 리소스:
- S3 버킷 (정적 파일 저장)
- CloudFront Distribution (CDN)
- ACM Certificate (HTTPS)
- S3 Bucket Policy (보안)

### 5. DNS 설정

ACM Certificate 검증을 위해 DNS에 CNAME 레코드를 추가합니다.

```bash
# 검증 레코드 확인
terraform output acm_validation_records
```

## 📊 주요 리소스

### Backend
- **VPC**: 10.0.0.0/16
- **Public Subnets**: 10.0.0.0/24, 10.0.1.0/24 (Multi-AZ)
- **Private Subnets**: 10.0.10.0/24, 10.0.11.0/24 (Multi-AZ)
- **EC2**: Ubuntu 24.04 ARM64, t4g.small, 20GB gp3 EBS
- **Security Group**: SSH(22), HTTP(80), HTTPS(443)
- **CloudWatch**: 6개 Log Groups (시스템, Nginx, 애플리케이션)

### Frontend
- **S3**: Private bucket with versioning, encryption
- **CloudFront**: HTTPS only, Global CDN
- **ACM**: TLS 1.2+ certificate
- **Domain**: dev.routie.me

## 🔐 보안

- ✅ EBS 볼륨 암호화
- ✅ S3 서버 측 암호화 (AES256)
- ✅ S3 퍼블릭 액세스 완전 차단
- ✅ HTTPS 강제 (TLS 1.2+)
- ✅ CloudFront OAC로 S3 직접 접근 차단
- ✅ IAM 최소 권한 원칙
- ✅ SSH 키 기반 인증

## 📈 모니터링

### CloudWatch Logs
- `/aws/ec2/routie/syslog` - 시스템 로그
- `/aws/ec2/routie/nginx/access` - Nginx 접근 로그
- `/aws/ec2/routie/nginx/error` - Nginx 에러 로그
- `/aws/ec2/routie/application` - Spring Boot 로그
- `/aws/ec2/routie/exception` - 예외 로그 (JSON)
- `/aws/ec2/routie/request` - HTTP 요청 로그 (JSON)

### CloudWatch Metrics (Namespace: Routie/EC2)
- CPU, Memory, Disk, Network, Swap 사용률

### 로그 확인

```bash
# AWS CLI로 실시간 로그 확인
aws logs tail /aws/ec2/routie/application --follow

# CloudWatch Insights 쿼리
# AWS Console → CloudWatch → Logs Insights
```

## 🛠️ 운영

### Backend 애플리케이션 배포

```bash
# EC2 접속
ssh -i key.pem ubuntu@<ELASTIC_IP>

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

### Backend
- EC2 t4g.small: ~$13
- EBS 20GB gp3: ~$2
- CloudWatch Logs: ~$1
- **총 예상**: ~$16-20/월

### Frontend
- S3 Storage (10GB): ~$0.5
- CloudFront: ~$1-3 (트래픽에 따라)
- **총 예상**: ~$1-5/월

**전체 예상 비용**: ~$17-25/월

## 📚 추가 문서

- **[INFRASTRUCTURE_GUIDE.md](./INFRASTRUCTURE_GUIDE.md)** - 전체 인프라 상세 가이드
  - 아키텍처 다이어그램
  - 리소스 상세 설명
  - 배포 가이드
  - 트러블슈팅
  - 보안 고려사항
  - CI/CD 통합

## 🔄 리소스 삭제

```bash
# Frontend 삭제
cd terraform/frontend/environments/dev
terraform destroy

# Backend 삭제
cd terraform/backend/environments/dev
terraform destroy

# Bootstrap 삭제 (선택적)
cd terraform/backend/bootstrap
terraform destroy

cd terraform/frontend/bootstrap
terraform destroy
```

⚠️ **주의**: Bootstrap을 삭제하면 Terraform State도 함께 삭제됩니다!

## 🐛 트러블슈팅

자주 발생하는 문제와 해결 방법은 [INFRASTRUCTURE_GUIDE.md의 트러블슈팅 섹션](./INFRASTRUCTURE_GUIDE.md#-트러블슈팅)을 참고하세요.

## 📞 지원

이슈 발생 시:
1. [INFRASTRUCTURE_GUIDE.md](./INFRASTRUCTURE_GUIDE.md) 트러블슈팅 섹션 확인
2. Terraform 로그 확인: `TF_LOG=DEBUG terraform apply`
3. AWS CloudWatch Logs 확인
4. GitHub 저장소에 이슈 등록

---

**작성일**: 2025-11-22  
**프로젝트**: Routie  
**Terraform**: v1.6+  
**AWS Provider**: v5.0+

