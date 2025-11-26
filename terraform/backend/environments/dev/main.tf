locals {
  base_tags = merge(var.base_tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

module "compute" {
  source = "../../modules/compute"

  project_name   = var.project_name
  environment    = var.environment
  s3_bucket_name = "${var.project_name}-${var.environment}-key-storage"

  base_tags = local.base_tags
}

module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  region       = var.region
  environment  = var.environment

  base_tags = local.base_tags
}

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

module "application" {
  source = "../../modules/application"

  project_name = var.project_name
  environment  = var.environment

  instance_type = "t4g.small"
  volume_type   = "gp3"
  volume_size   = 20

  vpc_id                     = module.network.vpc_id
  public_subnet_id           = module.network.public_subnet_a_id
  key_pair_name              = module.compute.key_pair_name
  iam_instance_profile_name  = module.iam.instance_profile_name

  base_tags = local.base_tags
}
