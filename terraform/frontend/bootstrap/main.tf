resource "aws_s3_bucket" "bucket" {
  for_each = toset(var.environments)

  bucket              = "${var.project_name}-${var.area}-${each.key}-terraform-state"
  object_lock_enabled = true

  tags = {
    Project     = var.project_name
    Environment = each.key
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  for_each = aws_s3_bucket.bucket

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  for_each = aws_s3_bucket.bucket

  bucket = each.value.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "object_lock_config" {
  for_each = aws_s3_bucket.bucket

  bucket = each.value.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 1
    }
  }
}
