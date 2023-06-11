locals {
  s3_origin_id                      = local.bucketName
}

###################################
# IAM Policy Document
###################################
data "aws_iam_policy_document" "read_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.bucket.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [module.s3_bucket.s3_bucket_arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.bucket.iam_arn]
    }
  }
}
###################################
# S3 Bucket Policy
###################################
resource "aws_s3_bucket_policy" "read_gitbook" {
  bucket                            = module.s3_bucket.s3_bucket_id
  policy                            = data.aws_iam_policy_document.read_bucket.json
}

resource "aws_cloudfront_origin_access_control" "bucket" {
  name                              = local.bucketName
  description                       = "Cloudfront Policy for ${local.bucketName}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_identity" "bucket" {
  comment                           = local.bucketName
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name                     = module.s3_bucket.s3_bucket_bucket_regional_domain_name
    #origin_access_control_id        = aws_cloudfront_origin_access_control.bucket.id
    origin_id                       = local.s3_origin_id

    s3_origin_config {
      origin_access_identity        = aws_cloudfront_origin_access_identity.bucket.cloudfront_access_identity_path
    }
  }

  enabled                           = true
  is_ipv6_enabled                   = true
  comment                           = "Cloudfront distribution for ${local.bucketName}"
  default_root_object               = "index.html"

  aliases                           = [local.bucketName]

  default_cache_behavior {
    allowed_methods                 = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods                  = ["GET", "HEAD"]
    target_origin_id                = local.bucketName

    forwarded_values {
      query_string                  = false

      cookies {
        forward                     = "none"
      }
    }

    viewer_protocol_policy          = "redirect-to-https"
    min_ttl                         = 0
    default_ttl                     = 3600
    max_ttl                         = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["DE"]
    }
  }

  price_class                      = "PriceClass_200"

  tags                             = local.tags

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = var.dependency.certificate.arn
    ssl_support_method             = "sni-only"
    #minimum_protocol_version = "TLSv1.2_2018"
  }
}