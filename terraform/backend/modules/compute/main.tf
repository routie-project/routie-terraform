resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = "${var.project_name}-${var.environment}-key-pair"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "aws_s3_bucket" "key_storage" {
  bucket = var.s3_bucket_name

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-${var.environment}-key-storage"
  })
}

resource "aws_s3_bucket_versioning" "key_storage_versioning" {
  bucket = aws_s3_bucket.key_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "key_storage_public_access_block" {
  bucket = aws_s3_bucket.key_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "key_storage_encryption" {
  bucket = aws_s3_bucket.key_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "private_key" {
  bucket  = aws_s3_bucket.key_storage.id
  key     = "keys/${var.project_name}-${var.environment}-private-key.pem"
  content = tls_private_key.private_key.private_key_pem

  server_side_encryption = "AES256"

  tags = merge(var.base_tags, {
    Name = "${var.project_name}-${var.environment}-private-key"
  })
}
