data "aws_region" "current" {}

resource "aws_vpc_endpoint" "resource" {
  vpc_id            = var.vpc_id
  vpc_endpoint_type = var.endpoint_type
  ip_address_type   = var.ip_address_type
  policy            = var.policy

  service_name = var.service_name != null ? var.service_name : format(
    "com.amazonaws.%s.%s", data.aws_region.current.region, var.service
  )

  subnet_ids          = var.endpoint_type == "Gateway" ? null : var.subnet_ids
  security_group_ids  = var.endpoint_type == "Gateway" ? null : var.security_group_ids
  private_dns_enabled = var.endpoint_type == "Interface" ? var.private_dns_enabled : null
  route_table_ids     = var.endpoint_type == "Gateway" ? var.route_table_ids : null

  tags = var.tags
}

output "id" {
  description = "The ID of the endpoint."
  value       = aws_vpc_endpoint.resource.id
}

output "arn" {
  description = "The ARN of the endpoint."
  value       = aws_vpc_endpoint.resource.arn
}

output "service_name" {
  description = "The full service name the endpoint resolves, whether it was supplied directly or assembled from the short name and the current region."
  value       = aws_vpc_endpoint.resource.service_name
}

output "dns_entry" {
  description = "DNS names the endpoint answers on, each with its hosted zone ID. Empty for a Gateway endpoint. Needed only when private_dns_enabled is false, because otherwise the service's own name already resolves to the endpoint."
  value       = aws_vpc_endpoint.resource.dns_entry
}

output "network_interface_ids" {
  description = "IDs of the elastic network interfaces the endpoint created, one per subnet. Empty for a Gateway endpoint."
  value       = aws_vpc_endpoint.resource.network_interface_ids
}

output "prefix_list_id" {
  description = "The prefix list the endpoint routes through. Gateway endpoints only. Reference this in a security group rule to allow traffic to the service without listing AWS address ranges."
  value       = aws_vpc_endpoint.resource.prefix_list_id
}

output "state" {
  description = "The state of the endpoint."
  value       = aws_vpc_endpoint.resource.state
}
