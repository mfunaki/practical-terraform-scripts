terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "=6.8.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_project_service" "sqladmin" {
  project            = var.project
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_service_networking" {
  project            = var.project
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_address" "static" {
  name = "ipv4-address"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "f1-micro"

  service_account {
    email  = google_service_account.sql_service_account.email
    scopes = ["https://www.googleapis.com/auth/sqlservice.admin"]
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash

      sudo apt update
      sudo apt install -y apache2 php php-mbstring php-xml php-mysqli

      wget http://ja.wordpress.org/latest-ja.tar.gz -P /tmp/
      tar zxvf /tmp/latest-ja.tar.gz -C /tmp
      sudo rm -rf /var/www/html/*
      sudo cp -r /tmp/wordpress/* /var/www/html/
      sudo chown www-data:www-data -R /var/www/html

      sudo systemctl enable apache2.service
      sudo systemctl restart apache2.service
    EOF
  }
  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.name
    access_config {
      nat_ip = google_compute_address.static.address
    }
  }

  tags = ["web"]
}

resource "google_compute_global_address" "private_ip_address" {
  provider      = google
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  deletion_policy         = "ABANDON"
  depends_on              = [google_compute_global_address.private_ip_address, google_compute_network.vpc_network]
}

resource "google_service_account" "sql_service_account" {
  account_id   = "cloud-sql"
  display_name = "Cloud SQL Service Account"
}

resource "google_sql_database_instance" "mysql" {
  name                = "mysql-instance"
  database_version    = "MYSQL_5_7"
  deletion_protection = false

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      private_network = google_compute_network.vpc_network.id
      ssl_mode        = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    }
  }

  depends_on = [google_project_service.sqladmin, google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "wordpress_db" {
  name     = "wpdb"
  instance = google_sql_database_instance.mysql.name
}

resource "google_sql_user" "root" {
  name     = "dba"
  instance = google_sql_database_instance.mysql.name
  password = random_password.wordpress.result
}

resource "random_password" "wordpress" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_compute_firewall" "main" {
  name    = "main-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}
