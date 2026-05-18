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

variable "source_dir" {
  description = "Path to the directory containing the Lambda source code"
  type        = string
}

variable "handler" {
  description = "Lambda handler in the format filename.function_name"
  type        = string
  default     = "handler.lambda_handler"
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 256
}

variable "environment_variables" {
  description = "Environment variables passed into the Lambda function"
  type        = map(string)
  default     = {}
}
