variable "env" { type = string }
variable "project_id" { type = string }
variable "region" {
  type    = string
  default = "asia-southeast1"
}

variable "subnet_cidr" {
  description = "Subnet CIDR range"
  type        = string
  default     = "10.0.0.0/16"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for Pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for Services"
  type        = string
  default     = "10.2.0.0/16"
}

variable "node_config" {
  description = "Configuration for worker nodes"
  type = object({
    machine_type = string
    min_nodes    = number
    max_nodes    = number
    disk_size_gb = number
    preemptible  = bool
  })
  default = {
    machine_type = "e2-medium"
    min_nodes    = 1
    max_nodes    = 3
    disk_size_gb = 20
    preemptible  = true
  }
}

variable "resource_labels" {
  type        = map(string)
  description = "Labels to apply to all resources"
  default     = {}
}

