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
│   ├── environments/
│   │   ├── dev/              # 개발 환경 배포 설정
│   │   └── prod/             # 프로덕션 환경 배포 설정
│   └── modules/
│       ├── network/          # VPC, Subnet, Security Group
│       ├── compute/          # SSH 키페어, S3
│       ├── iam/              # IAM 역할, CloudWatch 설정
│       └── application/      # EC2 인스턴스, EIP
└── frontend/                   # 프론트엔드 인프라 (S3, CloudFront)
    ├── bootstrap/             # Terraform State용 S3 초기 설정
    ├── environments/
    │   └── dev/              # 개발 환경 배포 설정
    └── modules/
        └── static-website/   # S3, CloudFront, ACM
```

## 🚀 빠른 시작

### 1. Backend State 버킷 생성

```bash
cd terraform/backend/bootstrap
terraform init
terraform apply
```

### 2. Backend 인프라 배포 (Dev 환경)

```bash
cd terraform/backend/environments/dev
terraform init
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
```

배포되는 리소스:
- VPC 및 네트워크 구성
- EC2 인스턴스 (Spring Boot 애플리케이션)
- IAM 역할 및 CloudWatch 모니터링 설정
- SSH 키페어 및 S3 저장소

### 3. SSH 키 다운로드

```bash
# Dev 환경 키 다운로드
aws s3 cp s3://routie-dev-key-storage/routie-dev-key-pair.pem ./routie-dev-key-pair.pem
chmod 400 routie-dev-key-pair.pem

# Prod 환경 키 다운로드
aws s3 cp s3://routie-prod-key-storage/routie-prod-key-pair.pem ./routie-prod-key-pair.pem
chmod 400 routie-prod-key-pair.pem
```

### 4. Frontend State 버킷 생성

```bash
cd terraform/frontend/bootstrap
terraform init
terraform apply
```

### 5. Frontend 인프라 배포 (Dev 환경)

```bash
cd terraform/frontend/environments/dev
terraform init
terraform plan
terraform apply
```

배포되는 리소스:
- S3 버킷 (정적 웹사이트 호스팅)
- CloudFront Distribution (CDN)
- ACM 인증서 (HTTPS)
- Route53 검증 레코드

### 6. ACM 인증서 검증

```bash
# 검증 레코드 확인
terraform output acm_validation_records
```

출력된 CNAME 레코드를 도메인 DNS 설정에 추가하여 인증서를 검증하세요.

## 🔧 주요 명령어

```bash
# 초기화
terraform init

# 플랜 확인
terraform plan

# 배포
terraform apply

# 리소스 삭제
terraform destroy

# 특정 리소스만 삭제
terraform destroy -target=resource_type.resource_name

# State 확인
terraform state list
terraform state show resource_type.resource_name
```

## 📝 환경 변수

Backend 및 Frontend 배포 시 필요한 주요 변수들:

### Backend 환경 변수
- `aws_region`: AWS 리전 (기본값: ap-northeast-2)
- `environment`: 환경 이름 (dev, prod)
- `project_name`: 프로젝트 이름 (routie)
- `instance_type`: EC2 인스턴스 타입
- `allowed_ssh_ip`: SSH 접근 허용 IP

### Frontend 환경 변수
- `aws_region`: AWS 리전
- `environment`: 환경 이름
- `domain_name`: 도메인 이름
- `bucket_name`: S3 버킷 이름

## 🔐 보안

- SSH 키는 S3에 암호화되어 저장됩니다
- Security Group을 통한 접근 제어
- IAM 역할 기반 권한 관리
- HTTPS 강제 적용 (CloudFront)

## 📊 모니터링

- CloudWatch Logs를 통한 애플리케이션 로그 수집
- CloudWatch Metrics를 통한 시스템 메트릭 모니터링
- 로그 그룹: `/routie/{environment}`
