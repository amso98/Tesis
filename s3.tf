############ S3 SERVICE ###########
/*resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "frontend-bucket-${random_string.unique_suffix.result}"

  force_destroy = true  # Opcional: si necesitas eliminar el bucket con objetos.

  tags = {
    Name        = "UCB_test"
    Environment = "Production"
  }
}
resource "aws_s3_bucket_public_access_block" "frontend_public_access_block" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_string" "unique_suffix" {
  length  = 6
  special = false
  upper   = false
}

############ S3 POLICY ###########
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "s3:GetObject"
        Effect    = "Allow"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn
        }
      }
    ]
  })
}*/