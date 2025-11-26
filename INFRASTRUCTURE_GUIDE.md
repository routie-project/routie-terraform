# Routie Terraform 인프라 구성 문서

> **작성일**: 2025-11-22  
> **프로젝트**: Routie  
> **IaC 도구**: Terraform

---

## 📑 목차

1. [개요](#-개요)
2. [프로젝트 구조](#-프로젝트-구조)
3. [Backend 인프라](#-backend-인프라)
4. [Frontend 인프라](#-frontend-인프라)
5. [디렉토리 역할 설명](#-디렉토리-역할-설명)
6. [배포 가이드](#-배포-가이드)
7. [리소스 상세 설명](#-리소스-상세-설명)

---

## 🎯 개요

Routie 프로젝트의 AWS 인프라를 Terraform으로 관리하는 IaC(Infrastructure as Code) 구성입니다.

### **핵심 특징**

- **멀티 환경 지원**: dev, prod 등 여러 환경 분리
- **모듈화 설계**: 재사용 가능한 컴포넌트 구조
- **State 관리**: S3 Backend를 통한 안전한 상태 관리
- **보안 강화**: 암호화, IAM, 최소 권한 원칙 적용
- **모니터링**: CloudWatch를 통한 로그 및 메트릭 수집

### **인프라 구성**

```
Backend: EC2 (Spring Boot) + VPC + CloudWatch
Frontend: S3 + CloudFront + ACM (HTTPS)
```

---

## 📂 프로젝트 구조

```
terraform/
├── backend/                    # 백엔드 인프라 (EC2, VPC)
│   ├── bootstrap/             # Terraform State용 S3 초기 설정
│   ├── environments/          # 환경별 배포 설정
│   │   └── dev/
│   └── modules/               # 재사용 가능한 모듈
│       ├── application/       # EC2 애플리케이션 서버
│       ├── compute/          # SSH 키페어, S3
│       ├── iam/              # IAM 역할, CloudWatch 설정
│       └── network/          # VPC, 서브넷, 라우팅
│
└── frontend/                  # 프론트엔드 인프라 (S3, CloudFront)
    ├── bootstrap/            # Terraform State용 S3 초기 설정
    ├── environments/         # 환경별 배포 설정
    │   └── dev/
    └── modules/              # 재사용 가능한 모듈
        └── static-website/   # S3 + CloudFront 정적 웹사이트
```

---

## 🖥️ Backend 인프라

### **아키텍처 다이어그램**

```
Internet
    ↓
Internet Gateway
    ↓
Public Subnet (10.0.0.0/24, 10.0.1.0/24)
    ↓
EC2 Instance (t4g.small)
    ├── Elastic IP
    ├── Security Group (SSH, HTTP, HTTPS)
    ├── IAM Instance Profile
    └── CloudWatch Agent
    ↓
Private Subnet (10.0.10.0/24, 10.0.11.0/24)
```

### **1. Network 모듈** (`modules/network/`)

**구성 요소**:
- **VPC**: `10.0.0.0/16`
- **Public Subnets**: 
  - `10.0.0.0/24` (ap-northeast-2a)
  - `10.0.1.0/24` (ap-northeast-2b)
- **Private Subnets**: 
  - `10.0.10.0/24` (ap-northeast-2a)
  - `10.0.11.0/24` (ap-northeast-2b)
- **Internet Gateway**: 외부 통신
- **Route Table**: Public 서브넷용 IGW 라우팅

**특징**:
- DNS 지원 활성화 (`enable_dns_support`, `enable_dns_hostnames`)
- Multi-AZ 구성으로 고가용성 확보
- Public/Private 서브넷 분리

**리소스**:
```terraform
- aws_vpc.vpc
- aws_subnet.public_a, public_b
- aws_subnet.private_a, private_b
- aws_internet_gateway.igw
- aws_route_table.public_rt
- aws_route_table_association.public_rt_a, public_rt_b
```

---

### **2. Compute 모듈** (`modules/compute/`)

**구성 요소**:
- **SSH 키페어**: TLS 4096비트 RSA 키 자동 생성
- **S3 Bucket**: 프라이빗 키 안전 보관
  - 버저닝 활성화
  - 암호화 (AES256)
  - 퍼블릭 액세스 차단

**특징**:
- SSH 키를 S3에 암호화하여 저장
- Terraform 외부에서 키 복구 가능

**리소스**:
```terraform
- tls_private_key.private_key
- aws_key_pair.key_pair
- aws_s3_bucket.key_storage
- aws_s3_bucket_versioning
- aws_s3_bucket_public_access_block
- aws_s3_bucket_server_side_encryption_configuration
- aws_s3_object.private_key
```

---

### **3. Application 모듈** (`modules/application/`)

**구성 요소**:
- **EC2 Instance**:
  - AMI: Ubuntu 24.04 ARM64
  - Instance Type: `t4g.small` (2 vCPU, 2GB RAM)
  - EBS: 20GB gp3 (암호화)
  - 배치: Public Subnet A
- **Security Group**:
  - Inbound: SSH(22), HTTP(80), HTTPS(443)
  - Outbound: 모든 트래픽 허용
- **Elastic IP**: 고정 퍼블릭 IP
- **IAM Instance Profile**: CloudWatch Agent 권한

**User Data 자동 설치**:
```bash
✅ Docker & Docker Compose
✅ Nginx
✅ 4GB Swap 파일
✅ CloudWatch Agent
```

**CloudWatch Agent 설정**:
- **메트릭 수집**: CPU, Memory, Disk, Network, Swap
- **로그 수집**: 
  - 시스템 로그: `/var/log/syslog`
  - Nginx 로그: `/var/log/nginx/access.log`, `error.log`
  - 애플리케이션 로그: `/home/ubuntu/logs/routie.log`
  - 예외 로그: `/home/ubuntu/logs/routie-exception.json`
  - 요청 로그: `/home/ubuntu/logs/routie-request.json`

**리소스**:
```terraform
- data.aws_ami.app_ami
- aws_security_group.app_sg
- aws_instance.app_instance
- aws_eip.app_eip
- aws_eip_association.app_eip_association
```

---

### **4. IAM 모듈** (`modules/iam/`)

**구성 요소**:
- **IAM Role**: `ec2_cloudwatch_agent_role`
  - CloudWatchAgentServerPolicy (관리형 정책)
  - AmazonSSMManagedInstanceCore (SSM 접속용)
- **IAM Instance Profile**: EC2에 연결
- **CloudWatch Log Groups** (7일 보관):
  - `/aws/ec2/routie/syslog`
  - `/aws/ec2/routie/nginx/access`
  - `/aws/ec2/routie/nginx/error`
  - `/aws/ec2/routie/application`
  - `/aws/ec2/routie/exception`
  - `/aws/ec2/routie/request`

**특징**:
- EC2가 CloudWatch에 메트릭/로그 전송 가능
- SSM Session Manager로 SSH 없이 EC2 접속 가능

**리소스**:
```terraform
- aws_iam_role.ec2_cw_role
- aws_iam_role_policy_attachment.cw_agent_policy_attach
- aws_iam_role_policy_attachment.ssm_policy_attach
- aws_iam_instance_profile.ec2_cw_profile
- aws_cloudwatch_log_group (6개)
```

---

### **5. Dev 환경** (`environments/dev/`)

**모듈 조합**:
```terraform
module "compute"      # SSH 키페어 생성
module "network"      # VPC, 서브넷 생성
module "iam"          # CloudWatch 권한 설정
module "application"  # EC2 인스턴스 생성
```

**Backend 설정**:
- State 저장: S3 버킷 (`routie-backend-dev-terraform-state`)
- State Locking: DynamoDB (선택적)

**주요 변수**:
```terraform
project_name = "routie"
environment  = "dev"
region       = "ap-northeast-2"
```

---

## 🌐 Frontend 인프라

### **아키텍처 다이어그램**

```
User (HTTPS)
    ↓
CloudFront (CDN)
    ├── ACM Certificate (dev.routie.me)
    └── Origin Access Control (OAC)
        ↓
    S3 Bucket (Private)
        └── Static Files (React Build)
```

### **1. Static Website 모듈** (`modules/static-website/`)

**구성 요소**:

#### **S3 Bucket**
- 버킷명: `routie-frontend-dev`
- 설정:
  - ✅ 버저닝 활성화
  - ✅ 암호화 (AES256)
  - ✅ 퍼블릭 액세스 완전 차단
  - ✅ Lifecycle 정책 (이전 버전 7일 후 삭제)

#### **ACM Certificate**
- 도메인: `dev.routie.me`
- 검증 방법: DNS
- 리전: `us-east-1` (CloudFront 요구사항)

#### **CloudFront Distribution**
- HTTPS Only (HTTP → HTTPS 리다이렉트)
- 캐시 정책: AWS 관리형 정책 사용
- 압축: 활성화
- 커스텀 에러 페이지:
  - 403, 404 → `/index.html` (SPA 라우팅 지원)
- **Origin Access Control (OAC)**: S3를 완전히 프라이빗하게 유지

#### **S3 Bucket Policy**
- CloudFront만 S3 접근 허용
- 조건: CloudFront Distribution ARN 일치 시에만

**특징**:
- **완전한 보안**: S3는 퍼블릭 접근 불가, CloudFront를 통해서만 접근
- **SPA 지원**: React Router 등의 클라이언트 라우팅 지원
- **HTTPS 강제**: 모든 트래픽 암호화
- **글로벌 CDN**: CloudFront의 엣지 로케이션 활용

**리소스**:
```terraform
- aws_s3_bucket.bucket
- aws_s3_bucket_lifecycle_configuration
- aws_s3_bucket_public_access_block
- aws_s3_bucket_versioning
- aws_s3_bucket_server_side_encryption_configuration
- aws_acm_certificate.acm_certificate
- aws_cloudfront_origin_access_control.oac
- aws_cloudfront_distribution.cdn
- aws_s3_bucket_policy.bucket_policy
```

---

### **2. Dev 환경** (`environments/dev/`)

**모듈 조합**:
```terraform
module "static_website"  # S3 + CloudFront
```

**Backend 설정**:
- State 저장: S3 버킷 (`routie-frontend-dev-terraform-state`)

**주요 변수**:
```terraform
project_name = "routie"
area         = "frontend"
environment  = "dev"
fqdn         = "dev.routie.me"
```

---

## 📚 디렉토리 역할 설명

### **1. `bootstrap/`**

**목적**: Terraform State를 저장할 S3 버킷 초기 생성

**특징**:
- 한 번만 실행 (최초 설정)
- 환경별(dev, prod) S3 버킷 생성
- Object Lock 활성화 (state 파일 보호)
- 버저닝 활성화
- 퍼블릭 액세스 차단

**버킷 명명 규칙**:
```
{project_name}-{area}-{environment}-terraform-state

예시:
- routie-backend-dev-terraform-state
- routie-backend-prod-terraform-state
- routie-frontend-dev-terraform-state
```

**사용법**:
```bash
cd terraform/backend/bootstrap
terraform init
terraform apply
```

---

### **2. `environments/{env}/`**

**목적**: 실제 배포할 환경 설정 (dev, prod 등)

**특징**:
- 모듈들을 조합하여 전체 인프라 구성
- 환경별 변수 설정
- Backend 설정 (S3에 state 저장)

**주요 파일**:
- `main.tf`: 모듈 호출 및 구성
- `variables.tf`: 입력 변수 정의
- `outputs.tf`: 출력 값 정의
- `provider.tf`: AWS Provider 설정
- `backend.tf`: Terraform Backend 설정 (S3)

**사용법**:
```bash
cd terraform/backend/environments/dev
terraform init
terraform plan
terraform apply
```

---

### **3. `modules/{module_name}/`**

**목적**: 재사용 가능한 인프라 컴포넌트

**특징**:
- 독립적으로 동작 가능
- 여러 환경에서 재사용
- 입력/출력 인터페이스 정의

**모듈 목록**:

| 모듈 | 위치 | 역할 |
|------|------|------|
| **network** | `backend/modules/network/` | VPC, 서브넷, 라우팅 |
| **compute** | `backend/modules/compute/` | SSH 키, 키 저장용 S3 |
| **application** | `backend/modules/application/` | EC2, 보안그룹, EIP |
| **iam** | `backend/modules/iam/` | IAM 역할, CloudWatch 설정 |
| **static-website** | `frontend/modules/static-website/` | S3, CloudFront, ACM |

**모듈 파일 구조**:
```
module/
├── main.tf         # 리소스 정의
├── variables.tf    # 입력 변수
├── outputs.tf      # 출력 값
├── provider.tf     # Provider 설정 (필요시)
└── *.tpl          # 템플릿 파일 (필요시)
```

---

## 🚀 배포 가이드

### **사전 준비**

1. **AWS CLI 설치 및 자격증명 설정**
```bash
aws configure
# AWS Access Key ID, Secret Access Key, Region 입력
```

2. **Terraform 설치**
```bash
# macOS
brew install terraform

# 버전 확인
terraform version
```

---

### **배포 순서**

#### **1단계: Bootstrap (최초 1회)**

Backend와 Frontend 각각의 State 버킷을 생성합니다.

**Backend State 버킷 생성**:
```bash
cd terraform/backend/bootstrap
terraform init
terraform apply
```

**Frontend State 버킷 생성**:
```bash
cd terraform/frontend/bootstrap
terraform init
terraform apply
```

#### **2단계: Backend 인프라 배포**

```bash
cd terraform/backend/environments/dev

# 초기화 (Backend 설정)
terraform init

# 실행 계획 확인
terraform plan

# 인프라 배포
terraform apply

# 출력 값 확인
terraform output
```

**배포되는 리소스**:
- VPC, 서브넷, Internet Gateway, Route Table
- SSH 키페어, 키 저장용 S3
- IAM 역할, CloudWatch Log Groups
- EC2 인스턴스, 보안그룹, Elastic IP

#### **3단계: Frontend 인프라 배포**

```bash
cd terraform/frontend/environments/dev

# 초기화
terraform init

# 실행 계획 확인
terraform plan

# 인프라 배포
terraform apply

# 출력 값 확인 (CloudFront URL 등)
terraform output
```

**배포되는 리소스**:
- S3 버킷 (정적 파일 저장)
- ACM Certificate (HTTPS)
- CloudFront Distribution
- S3 Bucket Policy

#### **4단계: DNS 설정**

ACM Certificate 검증을 위해 DNS에 CNAME 레코드를 추가해야 합니다.

```bash
# ACM Certificate의 검증 레코드 확인
terraform output acm_validation_records
```

Route53 또는 사용 중인 DNS 서비스에 CNAME 레코드 추가:
```
Name: _xxxxxxxxx.dev.routie.me
Type: CNAME
Value: _xxxxxxxxx.acm-validations.aws.
```

---

### **배포 후 확인**

#### **Backend 확인**

```bash
# EC2 인스턴스 접속
ssh -i path/to/key.pem ubuntu@<ELASTIC_IP>

# CloudWatch Agent 상태 확인
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a query -m ec2 -c default

# Docker 확인
docker --version
docker ps
```

#### **Frontend 확인**

```bash
# CloudFront URL로 접속
curl https://dev.routie.me

# S3 버킷에 파일 업로드 테스트
aws s3 cp ./build/ s3://routie-frontend-dev/ --recursive

# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

---

### **인프라 삭제**

리소스를 삭제할 때는 역순으로 진행합니다.

```bash
# 1. Frontend 삭제
cd terraform/frontend/environments/dev
terraform destroy

# 2. Backend 삭제
cd terraform/backend/environments/dev
terraform destroy

# 3. Bootstrap 삭제 (선택적)
cd terraform/backend/bootstrap
terraform destroy

cd terraform/frontend/bootstrap
terraform destroy
```

⚠️ **주의**: Bootstrap을 삭제하면 Terraform State 파일도 함께 삭제됩니다!

---

## 📊 리소스 상세 설명

### **Backend 리소스 요약**

| 리소스 타입 | 개수 | 용도 |
|------------|------|------|
| VPC | 1 | 격리된 네트워크 환경 |
| Subnet | 4 | Public 2개, Private 2개 (Multi-AZ) |
| Internet Gateway | 1 | 외부 인터넷 연결 |
| Route Table | 1 | Public 서브넷 라우팅 |
| Security Group | 1 | EC2 방화벽 규칙 |
| EC2 Instance | 1 | 애플리케이션 서버 |
| Elastic IP | 1 | 고정 퍼블릭 IP |
| Key Pair | 1 | SSH 접속용 키 |
| S3 Bucket | 2 | 키 저장, Terraform State |
| IAM Role | 1 | CloudWatch 권한 |
| IAM Instance Profile | 1 | EC2에 역할 연결 |
| CloudWatch Log Group | 6 | 로그 수집 |

**월간 예상 비용 (dev 환경)**:
- EC2 t4g.small: ~$13
- EBS 20GB gp3: ~$2
- Elastic IP: $0 (EC2 연결 시)
- Data Transfer: 변동
- CloudWatch Logs: ~$1
- **총 예상**: ~$16-20/월

---

### **Frontend 리소스 요약**

| 리소스 타입 | 개수 | 용도 |
|------------|------|------|
| S3 Bucket | 2 | 정적 파일, Terraform State |
| CloudFront Distribution | 1 | CDN |
| ACM Certificate | 1 | HTTPS 인증서 |
| CloudFront OAC | 1 | S3 접근 제어 |

**월간 예상 비용 (dev 환경)**:
- S3 Storage: ~$0.5 (10GB 가정)
- CloudFront: ~$1 (트래픽에 따라 변동)
- ACM Certificate: $0 (퍼블릭 인증서 무료)
- **총 예상**: ~$1-5/월

---

## 🔐 보안 고려사항

### **적용된 보안 조치**

#### **1. 네트워크 보안**
- ✅ Public/Private 서브넷 분리
- ✅ Security Group으로 포트 제한
- ✅ HTTPS 강제 (CloudFront)

#### **2. 데이터 암호화**
- ✅ EBS 볼륨 암호화
- ✅ S3 서버 측 암호화 (AES256)
- ✅ HTTPS 전송 암호화 (TLS 1.2+)

#### **3. 접근 제어**
- ✅ S3 퍼블릭 액세스 완전 차단
- ✅ IAM 역할 최소 권한 원칙
- ✅ CloudFront OAC로 S3 직접 접근 차단
- ✅ SSH 키 기반 인증

#### **4. 감사 및 모니터링**
- ✅ S3 버저닝 활성화
- ✅ CloudWatch Logs 수집
- ✅ Terraform State Object Lock

### **추가 권장사항**

#### **고려할 보안 강화**
- [ ] AWS WAF (웹 방화벽) 적용
- [ ] VPC Flow Logs 활성화
- [ ] Secrets Manager (DB 비밀번호 등)
- [ ] AWS Config (리소스 변경 추적)
- [ ] GuardDuty (위협 탐지)
- [ ] CloudTrail (API 호출 로깅)

#### **운영 보안**
- [ ] MFA(Multi-Factor Authentication) 활성화
- [ ] IAM 사용자 대신 IAM Role 사용
- [ ] 정기적인 보안 패치 적용
- [ ] 사용하지 않는 리소스 삭제

---

## 🛠️ 운영 가이드

### **CloudWatch 로그 확인**

```bash
# AWS CLI로 로그 확인
aws logs tail /aws/ec2/routie/application --follow

# 특정 시간 범위 로그 확인
aws logs filter-log-events \
  --log-group-name /aws/ec2/routie/exception \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --end-time $(date -u +%s)000
```

### **CloudWatch Insights 쿼리 예시**

**에러 로그 분석**:
```sql
fields @timestamp, level, logger, message
| filter log_group = "/aws/ec2/routie/application"
| filter level = "ERROR"
| sort @timestamp desc
| limit 50
```

**HTTP 요청 통계**:
```sql
fields @timestamp
| filter log_group = "/aws/ec2/routie/request"
| stats count() by bin(5m)
```

**예외 집계**:
```sql
fields @timestamp, exception, message
| filter log_group = "/aws/ec2/routie/exception"
| stats count() by exception
| sort count desc
```

---

### **애플리케이션 배포 (Backend)**

```bash
# EC2에 SSH 접속
ssh -i key.pem ubuntu@<ELASTIC_IP>

# 애플리케이션 배포 (Docker 예시)
cd /home/ubuntu/app
docker-compose pull
docker-compose up -d

# 로그 확인
docker-compose logs -f

# 로그 디렉토리 확인
ls -la /home/ubuntu/logs/
```

---

### **프론트엔드 배포**

```bash
# 로컬에서 빌드
npm run build

# S3에 업로드
aws s3 sync ./build/ s3://routie-frontend-dev/ --delete

# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

---

### **Terraform State 관리**

```bash
# State 목록 확인
terraform state list

# 특정 리소스 상세 정보
terraform state show aws_instance.app_instance

# State를 로컬로 가져오기
terraform state pull > terraform.tfstate.backup

# State에서 리소스 제거 (실제 리소스는 유지)
terraform state rm aws_instance.app_instance
```

---

### **리소스 업데이트**

```bash
# 특정 리소스만 업데이트
terraform apply -target=module.application.aws_instance.app_instance

# 변수 파일로 적용
terraform apply -var-file="prod.tfvars"

# 자동 승인 (CI/CD에서 사용)
terraform apply -auto-approve
```

---

## 🐛 트러블슈팅

### **문제 1: Terraform State Lock**

**증상**: 
```
Error: Error acquiring the state lock
```

**원인**: 다른 프로세스가 State를 사용 중이거나 비정상 종료

**해결**:
```bash
# DynamoDB에서 Lock 테이블 확인 및 삭제
# 또는 강제 unlock (주의!)
terraform force-unlock <LOCK_ID>
```

---

### **문제 2: ACM Certificate 검증 대기**

**증상**: CloudFront 배포 시 Certificate 대기 중

**원인**: DNS CNAME 레코드 미추가

**해결**:
1. `terraform output` 또는 AWS Console에서 검증 레코드 확인
2. DNS 제공자에 CNAME 레코드 추가
3. 검증 완료까지 대기 (최대 30분)

---

### **문제 3: CloudWatch Agent 미작동**

**증상**: CloudWatch에 로그/메트릭이 나타나지 않음

**해결**:
```bash
# EC2 접속 후 확인
sudo systemctl status amazon-cloudwatch-agent

# 로그 확인
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

# 재시작
sudo systemctl restart amazon-cloudwatch-agent
```

---

### **문제 4: S3 업로드 후 CloudFront에서 이전 파일 보임**

**증상**: S3는 업데이트되었지만 CloudFront는 캐시된 파일 제공

**해결**:
```bash
# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

---

## 📝 변수 참조

### **Backend 주요 변수**

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `project_name` | string | - | 프로젝트 이름 |
| `environment` | string | - | 환경 (dev, prod) |
| `region` | string | - | AWS 리전 |
| `instance_type` | string | t4g.small | EC2 인스턴스 타입 |
| `volume_size` | number | 20 | EBS 볼륨 크기 (GB) |
| `volume_type` | string | gp3 | EBS 볼륨 타입 |

### **Frontend 주요 변수**

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `project_name` | string | - | 프로젝트 이름 |
| `environment` | string | - | 환경 (dev, prod) |
| `area` | string | frontend | 영역 구분 |
| `fqdn` | string | - | 도메인 (예: dev.routie.me) |

---

## 🔄 CI/CD 통합

### **GitHub Actions 예시**

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [ main ]
    paths:
      - 'terraform/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Terraform Init
        run: |
          cd terraform/backend/environments/dev
          terraform init
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          
      - name: Terraform Plan
        run: |
          cd terraform/backend/environments/dev
          terraform plan
          
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: |
          cd terraform/backend/environments/dev
          terraform apply -auto-approve
```

---

## 📚 참고 자료

### **공식 문서**
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [CloudWatch Agent Configuration](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)

### **Best Practices**
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)

---

## 📞 지원

**이슈 발생 시**:
1. 이 문서의 트러블슈팅 섹션 확인
2. Terraform 로그 확인: `TF_LOG=DEBUG terraform apply`
3. AWS CloudWatch Logs 확인
4. 프로젝트 저장소에 이슈 등록

---

**작성자**: Routie DevOps Team  
**최종 수정일**: 2025-11-22  
**문서 버전**: 1.0

