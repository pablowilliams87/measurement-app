terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

## TODO
# - Crear subnets en mas de una AZ para HA del entorno de produccion
# - Crear una lista con los entornos dev, staging, production, seria mas dinamica la creacion de nuevos entornos
# - Las instancias de produccion deberian tener un ASC
# - Produccion deberia tener configurado
#        --> https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider
#