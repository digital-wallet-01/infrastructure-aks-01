

##################################################################################
# IDENTITY RESOURCES
##################################################################################



##################################################################################
# ROLES AND PERMISSIONS
##################################################################################


# Grant AKS managed identity permission to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks-cluster.identity[0].principal_id
  depends_on = [
    azurerm_kubernetes_cluster.aks-cluster # Ensure cluster is created before assigning role # consider testing without it
  ]
}
