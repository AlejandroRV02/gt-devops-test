variable "app_name" {
  default = "mean-user-registration"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "frontend_image" {
  default = "gt-devops-test-frontend:latest"
}

variable "backend_image" {
  default = "gt-devops-test-backend:latest"
}


variable "mongodb_image" {
  default = "mongo:latest"
}

variable "zone_name" {
  description = "El nombre de la zona DNS para Route 53"
  type        = string
  default     = "${var.app_name}.com"
}

variable "zone_id" {
  description = "El ID de la zona DNS en Route 53"
  type        = string
}

variable "aws_region" {
  description = "La región de AWS donde se desplegarán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  type    = map(string)
  default = {
    Environment = "dev"
    Project     = var.app_name
  }
}
