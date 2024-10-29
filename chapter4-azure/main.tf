terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.6.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  numeric = true
  upper   = false
  lower   = true
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = "Japan East"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.vnet_name}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1-${random_string.suffix.result}"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "linux_nic" {
  name                = "linux-nic-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig-linux"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux_pip.id
  }
}

resource "azurerm_public_ip" "linux_pip" {
  name                = "linux-ip-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  domain_name_label   = "lin-test"
}

resource "random_password" "vm_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_linux_virtual_machine" "linux" {
  name                            = "linux"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = "Standard_B1s"
  admin_username                  = "adminuser"
  admin_password                  = random_password.vm_password.result
  network_interface_ids           = [azurerm_network_interface.linux_nic.id]
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  depends_on = [azurerm_network_interface_security_group_association.linux_nic_sg_assoc]
}

resource "azurerm_virtual_machine_extension" "linux_custom_script" {
  name                 = "extension-linux2"
  virtual_machine_id   = azurerm_linux_virtual_machine.linux.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "fileUris": ["https://gist.githubusercontent.com/jacopen/24bd7f58837722ad1019eb4a4c5f563b/raw/5ba73b106d28af48113cb03d98920b8f9d3d5d7f/setup-wp.sh"],
        "commandToExecute": "sh setup-wp.sh"
    }
SETTINGS
}

resource "azurerm_network_interface_security_group_association" "linux_nic_sg_assoc" {
  network_interface_id      = azurerm_network_interface.linux_nic.id
  network_security_group_id = azurerm_network_security_group.generic_sg.id
}

resource "azurerm_network_security_group" "generic_sg" {
  name                = "generic-sg-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "HTTP"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_mysql_flexible_server" "mysql_server" {
  name                = "mysql-server-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  administrator_login          = "dba"
  administrator_password       = random_password.wordpress.result
  version                      = "5.7"
  sku_name                     = "B_Standard_B1ms"
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  delegated_subnet_id = azurerm_subnet.db_subnet1.id

  lifecycle {
    ignore_changes = [
      zone
    ]
  }
}

resource "azurerm_mysql_flexible_database" "wordpress_db" {
  name                = "wpdb"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.mysql_server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}
resource "azurerm_mysql_flexible_server_configuration" "disable_tls" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.mysql_server.name
  value               = "OFF"
}

resource "azurerm_subnet" "db_subnet1" {
  name                 = "db-subnet-${random_string.suffix.result}"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = ["10.0.2.0/24"]
  delegation {
    name = "mysql_delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_mysql_flexible_server_firewall_rule" "subnet_access" {
  resource_group_name = azurerm_resource_group.main.name
  name                = "subnet-access"
  server_name         = azurerm_mysql_flexible_server.mysql_server.name
  start_ip_address    = "10.0.1.0"
  end_ip_address      = "10.0.2.255"
}

resource "random_password" "wordpress" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}