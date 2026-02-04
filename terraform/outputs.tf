output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "geth_rpc_endpoint" {
  description = "Geth RPC endpoint (once LoadBalancer is provisioned)"
  value       = "Run: kubectl get svc geth-service -n eth-nodes -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "grafana_endpoint" {
  description = "Grafana endpoint (once LoadBalancer is provisioned)"
  value       = "Run: kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}
