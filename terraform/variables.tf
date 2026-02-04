variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "blockchain-node-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.large"]  # 2 vCPU, 8GB RAM - good for blockchain nodes
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in node group"
  type        = number
  default     = 3
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in node group"
  type        = number
  default     = 2
}

variable "allowed_rpc_cidrs" {
  description = "CIDR blocks allowed to access RPC endpoints"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Restrict this in production!
}

variable "enable_monitoring" {
  description = "Enable Prometheus and Grafana monitoring"
  type        = bool
  default     = true
}

variable "geth_storage_size" {
  description = "Storage size for Geth data (GB)"
  type        = number
  default     = 100
}

variable "bitcoin_storage_size" {
  description = "Storage size for Bitcoin data (GB)"
  type        = number
  default     = 150
}

variable "deploy_geth" {
  description = "Deploy Geth (Ethereum) node"
  type        = bool
  default     = true
}

variable "deploy_bitcoin" {
  description = "Deploy Bitcoin node"
  type        = bool
  default     = false
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "changeme123!"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
