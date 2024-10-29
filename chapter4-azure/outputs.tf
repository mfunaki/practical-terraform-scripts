output "public_ip" {
  value = azurerm_public_ip.linux_pip.ip_address
}
output "db_endpoint" {
  value = azurerm_mysql_flexible_server.mysql_server.fqdn
}
output "db_password" {
  value     = random_password.wordpress.result
  sensitive = true
}

output "vm_password" {
  value     = random_password.vm_password.result
  sensitive = true
}