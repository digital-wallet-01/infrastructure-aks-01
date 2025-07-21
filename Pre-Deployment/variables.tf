
# Define variables for this module
variable "app_display_name" {
  description = "The display name for the Azure AD Application."
  type        = string
  default     = "github-aks-deployer"
}

variable "github_org" {
  description = "Your GitHub organization name (e.g., 'my-org')."
  type        = string
}

variable "github_repo_name" {
  description = "Your GitHub repository name (e.g., 'aks-infra')."
  type        = string
}

variable "github_branch_ref" {
  description = "The Git branch reference for the OIDC subject (e.g., 'refs/heads/main')."
  type        = string
  default     = "refs/heads/main"
}