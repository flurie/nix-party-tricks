terraform {
  required_version = "~> 1.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.4.0"
    }
  }
}
