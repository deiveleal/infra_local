terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30.0" # ou a versão que você declarou nos outros componentes
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  # Se você usar minikube ou docker desktop, você pode precisar explicitar o contexto:
  # config_context = "minikube" ou "docker-desktop"
}