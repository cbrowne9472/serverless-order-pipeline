variable "project" {
  description = "Project name — used as a prefix on all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}
