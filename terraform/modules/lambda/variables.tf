variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "function_name" {
  description = "Short name for this Lambda (e.g. order-intake, validation)"
  type        = string
}

variable "policy_json" {
  description = "JSON IAM policy document granting service-specific permissions. Leave empty for base role only."
  type        = string
  default     = ""
}
