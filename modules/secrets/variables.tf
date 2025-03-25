# variable "secret_name" {
#   description = "The name of the secret"
#   type        = string
# }

# variable "description" {
#   description = "The description of the secret"
#   type        = string
#   default     = null
# }

variable "project_name" {
  type        = string
  description = "Project name to be used to name the resources (Name tag)"
}

variable "oidc_issuer_url" {
  type = string
}

variable "aws_account_id" {
  type = string
}


# variable "secrets" {
#   type        = map(string)
#   description = "Map of secret keys and values"
# }