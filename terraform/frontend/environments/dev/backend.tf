terraform {
  backend "s3" {
    bucket       = "routie-frontend-dev-terraform-state"
    key          = "frontend.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
    encrypt      = true
  }
}
