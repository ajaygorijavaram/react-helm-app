terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ── Use existing AKS cluster ──
data "azurerm_kubernetes_cluster" "existing" {
  name                = "aks-cluster"
  resource_group_name = "aks-rg"
}

# ── Create ACR ──
resource "azurerm_resource_group" "rg" {
  name     = "react-app-rg"
  location = "Central India"
}

resource "azurerm_container_registry" "acr" {
  name                = "myreactacr98765"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# ── Assign AcrPull to existing AKS ──
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = data.azurerm_kubernetes_cluster.existing.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# ── Build and Push Docker Image ──resource "null_resource" "docker_build_push" {
  depends_on = [azurerm_container_registry.acr]

  provisioner "local-exec" {
    command = "az acr build --registry ${azurerm_container_registry.acr.name} --image react-app:latest ."
  }
}

# ── Helm Provider using existing AKS ──
provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.existing.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.existing.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.existing.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.existing.kube_config.0.cluster_ca_certificate)
  }
}

# ── Deploy Helm Chart to AKS ──
resource "helm_release" "react_app" {
  depends_on = [null_resource.docker_build_push, azurerm_role_assignment.aks_acr]

  name      = "react-app"
  chart     = "./helm-chart"

  set {
    name  = "replicaCount"
    value = "3"
  }

  set {
    name  = "image.repository"
    value = "${azurerm_container_registry.acr.login_server}/react-app"
  }

  set {
    name  = "image.tag"
    value = "latest"
  }
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}