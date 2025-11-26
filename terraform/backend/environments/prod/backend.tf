terraform {
  backend "s3" {
    bucket       = "routie-backend-prod-terraform-state"
    key          = "backend.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
    encrypt      = true
  }
}

