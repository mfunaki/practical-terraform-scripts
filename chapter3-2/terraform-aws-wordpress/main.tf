resource "aws_db_instance" "wordpress" {
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = "mysql"
  engine_version          = "5.7"
  instance_class          = var.rds_instance_class
  db_name                 = "wpdb"
  username                = "dba"
  password                = random_password.wordpress.result
  parameter_group_name    = "default.mysql5.7"
  multi_az                = false
  db_subnet_group_name    = var.db_subnet_group_name
  vpc_security_group_ids  = var.rds_security_group_ids
  backup_retention_period = "7"
  backup_window           = "01:00-02:00"
  skip_final_snapshot     = true
  max_allocated_storage   = 200
  identifier              = "${var.name}-db"
  tags = {
    Name = "${var.name}-db"
  }
}

resource "random_password" "wordpress" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  network_interface {
    network_interface_id = aws_network_interface.web.id
    device_index         = 0
  }
  user_data = file("wordpress.sh")
  tags = {
    Name = "${var.name}-web"
  }
}

resource "aws_network_interface" "web" {
  subnet_id       = var.subnet_id
  security_groups = var.security_group_ids
}

resource "aws_eip" "wordpress" {
  network_interface = aws_network_interface.web.id
  domain            = "vpc"
}
