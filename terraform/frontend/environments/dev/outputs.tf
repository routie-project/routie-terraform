output "acm_dns_validation_records" {
  value       = module.static_website.acm_dns_validation_records
  description = "Add the following CNAME records to your external DNS provider (e.g., Gabia). Continue after the certificate is issued."
}

output "bucket_name" {
  value = module.static_website.bucket_name
}

output "cloudfront_domain" {
  value = module.static_website.cloudfront_domain
}

output "cloudfront_id" {
  value = module.static_website.cloudfront_id
}

output "acm_certificate_arn" {
  value       = module.static_website.acm_certificate_arn
  description = "ACM Certificate ARN"
}

output "acm_certificate_status" {
  value       = module.static_website.acm_certificate_status
  description = "ACM Certificate Status"
}

output "website_url" {
  value       = module.static_website.website_url
  description = "Web site URL"
}
