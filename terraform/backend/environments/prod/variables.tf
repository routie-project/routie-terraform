variable "region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "project_name" {
  type        = string
  description = "Project name"
  default     = "routie"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "prod"
}

variable "base_tags" {
  type        = map(string)
  description = "Base tags to apply to resources"
  default     = {}
}

