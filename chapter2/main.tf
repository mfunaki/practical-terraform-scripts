terraform {
  required_providers {
    docker = {
        source = "kreuzwerker/docker"
        version = ">= 3.0.0"
    }
  }
}

provider "docker" {
  host = "npipe:////./pipe/docker_engine"
}

resource "docker_image" "nginx" {
    name = "nginx:latest"
    keep_locally = true
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name = "tutorial"
  ports {
    internal = 80
    external = 8000
  }
}

variable "container_name" {
    default = "tutorial"
    type = string
    description = "The name of the container"
}