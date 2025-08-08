


##################################################################################
# AKS Deployment and Service
##################################################################################

resource "kubernetes_deployment" "hello_nginx" {
  provider = kubernetes.aks
  depends_on = [local_file.current]
  metadata {
    name = "hello-nginx"
    labels = {
      app = "hello-nginx"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "hello-nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "hello_nginx" {
  provider   = kubernetes.aks
  metadata {
    name = "hello-nginx"
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-resource-group" = azurerm_resource_group.rg_terraform_aks.name
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.hello_nginx.metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type           = "LoadBalancer"
    load_balancer_ip = azurerm_public_ip.aks_static_ip.ip_address
  }
  depends_on = [
    azurerm_kubernetes_cluster.aks-cluster,
    azurerm_public_ip.aks_static_ip
  ]

}
