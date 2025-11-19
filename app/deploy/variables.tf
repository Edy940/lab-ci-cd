variable "cluster_name" {
  description = "Nome do cluster ECS"
  type        = string
  default     = "app-prod-cluster"
}

variable "desired_count" {
  description = "desired tasks"
  type        = number
  default     = 3
}

variable "subnets_id" {
  description = "Subnets IDs"
  type        = list(string)
}

variable "lb_name" {
  description = "Load Balancer Name"
  type        = string
  default     = "app-prod-nlb"
}