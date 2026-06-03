variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "order_intake_invoke_arn" {
  description = "Invoke ARN of the order intake Lambda"
  type        = string
}

variable "order_intake_function_name" {
  description = "Function name of the order intake Lambda — used to grant invoke permission"
  type        = string
}

variable "order_query_invoke_arn" {
  description = "Invoke ARN of the order query Lambda"
  type        = string
}

variable "order_query_function_name" {
  description = "Function name of the order query Lambda — used to grant invoke permission"
  type        = string
}

variable "dlq_monitor_invoke_arn" {
  description = "Invoke ARN of the DLQ monitor Lambda"
  type        = string
}

variable "dlq_monitor_function_name" {
  description = "Function name of the DLQ monitor Lambda"
  type        = string
}
