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