locals {
  s3_origin_id                      = "myS3Origin-${local.bucketName}"
}

resource "aws_cloudfront_origin_access_control" "bucket" {
  name                              = local.bucketName
  description                       = "Cloudfront Policy for ${local.bucketName}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name                     = module.s3_bucket.s3_bucket_bucket_regional_domain_name
    origin_access_control_id        = aws_cloudfront_origin_access_control.bucket.id
    origin_id                       = local.s3_origin_id
  }

  enabled                           = true
  is_ipv6_enabled                   = true
  comment                           = "Cloudfront distribution for ${local.bucketName}"
  default_root_object               = "index.html"

  aliases                           = [local.bucketName]

  default_cache_behavior {
    allowed_methods                 = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods                  = ["GET", "HEAD"]
    target_origin_id                = local.s3_origin_id

    forwarded_values {
      query_string                  = false

      cookies {
        forward                     = "none"
      }
    }

    viewer_protocol_policy          = "allow-all"
    min_ttl                         = 0
    default_ttl                     = 3600
    max_ttl                         = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string                 = false

      cookies {
        forward                    = "none"
      }
    }

    min_ttl                        = 0
    default_ttl                    = 3600
    max_ttl                        = 86400
    compress                       = true
    viewer_protocol_policy         = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type             = "blacklist"
      locations                    = ["CA"]
    }
  }

  price_class                      = "PriceClass_200"

  tags                             = local.tags

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = var.dependency.certificate.arn
    ssl_support_method             = "sni-only"
  }
}