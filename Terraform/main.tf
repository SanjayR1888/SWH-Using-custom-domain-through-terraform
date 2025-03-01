provider "aws" {
  region = "us-east-1"
}

// Create static-site hosting bucket
resource "aws_s3_bucket" "landing_page_bucket" {
  bucket = "landing-page-hosting-${var.environment}"

  tags = {
    Name        = "landing-page"
    Environment = var.environment
  }
}

// allow public access
resource "aws_s3_bucket_public_access_block" "landing_page_public_access" {
  bucket = aws_s3_bucket.landing_page_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

//enable static-site hosting
resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.landing_page_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

//add bucket policy
resource "aws_s3_bucket_policy" "landing_page_bucket_policy" {
  bucket = aws_s3_bucket.landing_page_bucket.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowGetObj",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.landing_page_bucket.id}/*"
    }
  ]
}
POLICY
}

// Create SSL certificate
resource "aws_acm_certificate" "ssl_cert" {
  domain_name       = var.domain
  validation_method = "DNS"

  tags = {
    Name        = "landing-page"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

//create route53 record
resource "aws_route53_record" "ssl_cert_validation_records" {
  for_each = {
    for dvo in aws_acm_certificate.ssl_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id

  depends_on = [aws_acm_certificate.ssl_cert]  # ✅ Ensures SSL cert is fully requested before adding the record
}

locals {
  s3_origin_id = "landing-page-access"
}

resource "aws_cloudfront_distribution" "static_site_distribution" {
  origin {
    domain_name = aws_s3_bucket.landing_page_bucket.bucket_regional_domain_name // static site domain name
    origin_id   = local.s3_origin_id

    // The custom_origin_config is for the website endpoint settings configured via the AWS Console.
    // https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_CustomOriginConfig.html
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
      origin_read_timeout = 30
      origin_keepalive_timeout = 5
    }
    connection_attempts = 3
    connection_timeout = 10
  }

  enabled             = true
  comment             = var.domain
  default_root_object = "index.html"

  aliases = [var.domain]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress = true
  }

  # ✅ This section ensures that CloudFront serves error.html for 404 errors
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/error.html"
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = var.environment
  }

  // The viewer_certificate is for the ssl certificate settings configured via the AWS Console.
  viewer_certificate {
    cloudfront_default_certificate = false
    ssl_support_method  = "sni-only"
    acm_certificate_arn = aws_acm_certificate.ssl_cert.arn
    minimum_protocol_version = "TLSv1.2_2021"
  }
  depends_on = [aws_acm_certificate.ssl_cert]  # ✅ Ensures SSL certificate is issued first
}

resource "aws_route53_record" "landing_page_A_record" {
  zone_id = var.route53_zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.static_site_distribution.domain_name
    zone_id = aws_cloudfront_distribution.static_site_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Upload files to S3 Bucket
resource "aws_s3_object" "website_files" {
  for_each = fileset("../website", "**")  # Upload everything in the website folder
  bucket   = aws_s3_bucket.landing_page_bucket.id
  key      = each.value
  source   = "../website/${each.value}"
  content_type = each.value
  etag     = filemd5("../website/${each.value}")
}