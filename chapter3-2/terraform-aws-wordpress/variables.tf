variable "name" {
  description = "作成されるリソース名"
  type        = string
}

variable "subnet_id" {
  description = "サブネットのID"
  type        = string
}

variable "security_group_ids" {
  description = "セキュリティグループのID"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI"
  type        = string
  default     = "ami-07c589821f2b353aa"
}

variable "instance_type" {
  description = "インスタンスタイプ"
  type        = string
  default     = "t3.micro"
}

variable "db_subnet_group_name" {
  description = "DBサブネットグループの名前"
  type        = string
}

variable "rds_security_group_ids" {
  description = "RDSに割り当てるセキュリティグループのID"
  type        = list(string)
}

variable "rds_instance_class" {
  description = "RDSインスタンスクラス"
  type        = string
  default     = "db.t3.micro"
}
