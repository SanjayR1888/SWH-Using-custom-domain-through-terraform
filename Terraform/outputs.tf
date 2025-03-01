output "domain_name" {
  description = "The custom domain name used for the website"
  value       = var.domain
}

output "cloudfront_distribution_id" {
  description = "The CloudFront distribution ID"
  value       = aws_cloudfront_distribution.static_site_distribution.id
}

output "cloudfront_distribution_domain" {
  description = "The CloudFront domain name for the website"
  value       = aws_cloudfront_distribution.static_site_distribution.domain_name
}

output "s3_website_endpoint" {
  description = "The S3 static website endpoint"
  value       = aws_s3_bucket_website_configuration.static_site.website_endpoint
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket used for static site hosting"
  value       = aws_s3_bucket.landing_page_bucket.id
}
