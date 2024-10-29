output "public_ip" {
  value = aws_eip.wordpress.public_ip
}
output "rds_endpoint" {
  value = aws_db_instance.wordpress.endpoint
}
output "rds_password" {
  value     = random_password.wordpress.result
  sensitive = true
}

output "wordpress1_public_ip" {
  value = module.wordpress.public_ip
}

output "wordpress1_rds_endpoint" {
  value = module.wordpress.rds_endpoint
}

output "wordpress1_rds_password" {
  value     = module.wordpress.rds_password
  sensitive = true
}
