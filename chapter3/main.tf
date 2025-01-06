terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.41.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_instance" "test_server" {
    ami = "ami-0eba6c58b7918d3a1"
    instance_type = "t2.micro"

    tags = {
      Name = "TestInstance"
    }
  
}