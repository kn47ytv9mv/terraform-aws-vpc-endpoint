# terraform-aws-vpc-endpoint

Terraform module for a VPC endpoint: private access to an AWS service, or
to a PrivateLink service another account publishes, without the traffic
leaving the AWS network.

## Cost

The two endpoint types are billed on entirely different models, and the
difference decides which one to reach for.

**Gateway endpoints carry no charge at all.** They apply only to S3 and
DynamoDB, they work by adding a prefix-list route rather than placing an
interface in a subnet, and there is no reason not to use one wherever a
private subnet talks to either service.

**Interface endpoints are billed per hour for every availability zone they
are placed in, plus a charge for each gigabyte processed.** That hourly
component runs whether or not anything uses the endpoint, and it
multiplies by the number of subnets in `subnet_ids`. Place one subnet per
zone that genuinely consumes the service, and no more.

The comparison that matters is against a NAT gateway rather than against
zero. Traffic to an AWS service from a private subnet otherwise goes out
through NAT, which is billed hourly and per gigabyte as well. At
meaningful volume an interface endpoint is cheaper, because its per
gigabyte rate is lower and the traffic stops crossing NAT. At low volume
the standing hourly charge can exceed what NAT would have cost for the
same traffic. **An interface endpoint is a saving at volume and a cost at
trickle**, so it is worth knowing which one a given service is before
adding it everywhere.

See AWS's
[PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/) page
for current rates.

## Design

`endpoint_type` defaults to `Interface`, because that is the type that
works for nearly every service. Gateway exists only for S3 and DynamoDB,
and the module rejects it for anything else at plan time rather than
letting AWS return an opaque error.

The two types take different inputs and the module enforces that. A
Gateway endpoint needs `route_table_ids` and takes no subnets or security
groups; an Interface endpoint needs `subnet_ids` and ignores route tables.
Whichever set does not apply is dropped rather than sent.

### Naming the service

`service` takes the short name — `s3`, `ssm`, `secretsmanager` — and the
module assembles `com.amazonaws.<region>.<service>` from the region it is
applied in, so the same configuration is portable across regions. For a
PrivateLink service published by another account, pass the full
`service_name` instead. Exactly one of the two is required.

### Private DNS is what makes it transparent

With `private_dns_enabled` left at its default, the service's ordinary
public hostname resolves to the endpoint from inside the VPC. Existing SDK
calls, CLI invocations and agents route through it with no configuration
change anywhere. Turn it off and every caller has to be pointed at the
endpoint's own DNS name, which is available as the `dns_entry` output.

### The policy is the boundary

Left null, AWS attaches a policy permitting full access to the service
through the endpoint. That makes the endpoint a private route and nothing
more. An endpoint policy is what turns it into a control — restricting
which buckets, which roles, or which accounts are reachable through this
path.

### Session Manager without internet access

The common reason to reach for this module is SSM. Session Manager is
often refused on the grounds that its control path leaves the network.
Three interface endpoints — `ssm`, `ssmmessages` and `ec2messages` — keep
that channel inside the VPC on PrivateLink, with no internet route and no
NAT gateway. Instances then need no inbound SSH, no bastion, and no public
egress for management traffic.

## Usage

```hcl
module "ssm_endpoint" {
  source = "kn47ytv9mv/vpc-endpoint/aws"

  vpc_id  = module.network.id
  service = "ssm"

  subnet_ids         = module.private_subnets[*].id
  security_group_ids = [module.endpoint_security_group.id]
}
```

Or directly from this repository:

```hcl
module "ssm_endpoint" {
  source = "github.com/kn47ytv9mv/terraform-aws-vpc-endpoint"

  vpc_id  = module.network.id
  service = "ssm"

  subnet_ids         = module.private_subnets[*].id
  security_group_ids = [module.endpoint_security_group.id]
}
```

An S3 gateway endpoint, which costs nothing and takes route tables rather
than subnets:

```hcl
module "s3_endpoint" {
  source = "kn47ytv9mv/vpc-endpoint/aws"

  vpc_id        = module.network.id
  service       = "s3"
  endpoint_type = "Gateway"

  route_table_ids = module.private_route_tables[*].id
}
```

A PrivateLink service published by another account:

```hcl
module "partner_endpoint" {
  source = "kn47ytv9mv/vpc-endpoint/aws"

  vpc_id       = module.network.id
  service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0123456789abcdef0"

  subnet_ids         = module.private_subnets[*].id
  security_group_ids = [module.endpoint_security_group.id]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.9 |
| aws | ~> 6.61 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| vpc_id | ID of the VPC the endpoint is created in. | `null` | no |
| service | Short AWS service name, e.g. `'s3'`, `'ssm'`. Assembled against the current region. | `null` | one of |
| service_name | Full service name, for a PrivateLink service or an explicit override. | `null` | one of |
| endpoint_type | `'Interface'`, `'Gateway'` or `'GatewayLoadBalancer'`. | `"Interface"` | no |
| subnet_ids | Subnets the interface is placed in. Interface endpoints only. | `null` | Interface |
| security_group_ids | Security groups applied to the interface. Interface endpoints only. | `null` | no |
| private_dns_enabled | Whether the service's public DNS name resolves to the endpoint inside the VPC. | `true` | no |
| route_table_ids | Route tables the prefix-list route is added to. Gateway endpoints only. | `null` | Gateway |
| ip_address_type | Address type (e.g. `'ipv4'`, `'ipv6'`, `'dualstack'`). | `null` | no |
| policy | JSON endpoint policy restricting what is reachable through the endpoint. | `null` | no |
| tags | A map of tags to assign to the endpoint. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the endpoint. |
| arn | The ARN of the endpoint. |
| service_name | The full service name the endpoint resolves. |
| dns_entry | DNS names the endpoint answers on, with hosted zone IDs. Empty for a Gateway endpoint. |
| network_interface_ids | IDs of the elastic network interfaces created, one per subnet. Empty for a Gateway endpoint. |
| prefix_list_id | The prefix list the endpoint routes through. Gateway endpoints only. |
| state | The state of the endpoint. |

## License

MIT — see [LICENSE.md](LICENSE.md).
