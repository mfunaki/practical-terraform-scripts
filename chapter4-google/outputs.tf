output "public_ip" {
  value = google_compute_address.static.address
}

output "db_endpoint" {
  value = google_sql_database_instance.mysql.private_ip_address
}
output "db_password" {
  value     = random_password.wordpress.result
  sensitive = true
}
