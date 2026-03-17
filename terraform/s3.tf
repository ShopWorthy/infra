resource "aws_s3_bucket" "exports" {
  bucket = "shopworthy-exports-${var.environment}"

  tags = {
    Environment = var.environment
  }
}

resource "aws_s3_bucket_acl" "exports_acl" {
  bucket = aws_s3_bucket.exports.id
  acl    = "public-read"
}

# Block public access settings — all disabled
resource "aws_s3_bucket_public_access_block" "exports" {
  bucket                  = aws_s3_bucket.exports.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
