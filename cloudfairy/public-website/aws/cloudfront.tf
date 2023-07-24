locals {
  s3_origin_id                      = "S3-${local.bucketName}"
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "Public Website"
  description                       = "Public Website Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name                     = module.s3_bucket.s3_bucket_bucket_regional_domain_name
    origin_id                       = local.s3_origin_id
    origin_access_control_id        = aws_cloudfront_origin_access_control.default.id
  
    # custom_origin_config {
    #   http_port              = "80"
    #   https_port             = "443"
    #   origin_protocol_policy = "http-only"
    #   origin_ssl_protocols   = ["TLSv1.2"]
    # }
  }

  enabled                           = true
  is_ipv6_enabled                   = true
  comment                           = "Cloudfront distribution for ${local.bucketName}"
  default_root_object               = var.properties.indexPage

  aliases                           = [local.bucketName]

  default_cache_behavior {
    allowed_methods                 = ["GET", "HEAD", "OPTIONS"]
    cached_methods                  = ["GET", "HEAD"]
    target_origin_id                = local.s3_origin_id

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
      restriction_type             = "none"
    }
  }

  price_class                      = "PriceClass_100"

  tags                             = local.tags

  custom_error_response {
    error_code                     = 404
    error_caching_min_ttl          = 0
    response_code                  = 404
    response_page_path             = "/${var.properties.errorPage}"
  }


  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = var.dependency.certificate.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2018"
  }
}

resource "aws_s3_bucket_policy" "cdn-cf-policy" {
  bucket                           = module.s3_bucket.s3_bucket_id
  policy                           = data.aws_iam_policy_document.website.json
}

data "aws_iam_policy_document" "website" {
  statement {
    sid                            = "AllowCloudFrontServicePrincipal"
    principals {
      type                         = "Service"
      identifiers                  = ["cloudfront.amazonaws.com"]
    }

    actions                        = [
      "s3:GetObject"
    ]

    resources                      = [
      "${module.s3_bucket.s3_bucket_arn}/*"
    ]

    condition {
      test                         = "ForAnyValue:StringEquals"
      variable                     = "AWS:SourceArn"
      values                       = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}