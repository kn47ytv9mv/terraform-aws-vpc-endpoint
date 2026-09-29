variable "vpc_id" {
  default     = null
  description = "ID of the VPC the endpoint is created in."
}

variable "service" {
  default     = null
  description = "Short AWS service name, e.g. 's3', 'ssm', 'ssmmessages', 'ec2messages', 'secretsmanager'. The module assembles the full service name from the current region. Use service_name instead for a PrivateLink service that is not an AWS one."

  validation {
    condition     = (var.service == null) != (var.service_name == null)
    error_message = "Set exactly one of service or service_name. service covers AWS services and builds the name from the current region; service_name takes a full name for anything else."
  }
}

variable "service_name" {
  default     = null
  description = "Full service name, e.g. 'com.amazonaws.us-east-1.s3' or a PrivateLink service name shared by another account. Overrides service."
}

variable "endpoint_type" {
  default     = "Interface"
  description = "Kind of endpoint (e.g. 'Interface', 'Gateway', or 'GatewayLoadBalancer'). Gateway is free and supports only S3 and DynamoDB; Interface works for almost every service and is billed hourly. See the README."

  validation {
    condition     = contains(["Interface", "Gateway", "GatewayLoadBalancer"], var.endpoint_type)
    error_message = "endpoint_type must be 'Interface', 'Gateway' or 'GatewayLoadBalancer'."
  }

  validation {
    condition     = var.endpoint_type != "Gateway" || var.service == null || contains(["s3", "dynamodb"], var.service)
    error_message = "Gateway endpoints exist only for S3 and DynamoDB. Every other service needs an Interface endpoint."
  }

  validation {
    condition     = var.endpoint_type != "Gateway" || length(coalesce(var.route_table_ids, [])) > 0
    error_message = "A Gateway endpoint needs route_table_ids. It works by adding a prefix-list route, not by placing an interface in a subnet."
  }

  validation {
    condition     = var.endpoint_type == "Gateway" || length(coalesce(var.subnet_ids, [])) > 0
    error_message = "An Interface endpoint needs subnet_ids. Place one subnet per availability zone you want the service reachable from."
  }
}

variable "subnet_ids" {
  default     = null
  description = "Subnets the interface is placed in, one per availability zone. Interface endpoints only. Each subnet adds an hourly charge, so place them only where the service is actually consumed."
}

variable "security_group_ids" {
  default     = null
  description = "Security groups applied to the interface. Interface endpoints only. Left null, the VPC default security group is used, which is rarely what is wanted — allow 443 from the consumers and nothing else."
}

variable "private_dns_enabled" {
  default     = true
  description = "Whether the service's public DNS name resolves to the endpoint inside the VPC. Interface endpoints only. True is what makes an endpoint transparent: existing SDK and CLI calls route through it with no configuration change."
}

variable "route_table_ids" {
  default     = null
  description = "Route tables the endpoint's prefix-list route is added to. Gateway endpoints only."
}

variable "ip_address_type" {
  default     = null
  description = "Address type for the endpoint (e.g. 'ipv4', 'ipv6', or 'dualstack'). Left null, AWS picks based on the subnets."
}

variable "policy" {
  default     = null
  description = "JSON endpoint policy restricting what can be reached through the endpoint. Left null, AWS attaches a policy allowing full access, so this is the control that turns an endpoint into a boundary rather than a route."
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the endpoint."
}
