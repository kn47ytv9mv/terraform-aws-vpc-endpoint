mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
}

variables {
  vpc_id     = "vpc-00000000000000001"
  service    = "ssm"
  subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
}

run "both_service_forms_at_once_is_rejected" {
  command = plan

  variables {
    service_name = "com.amazonaws.us-east-1.ssm"
  }

  expect_failures = [var.service]
}

run "neither_service_form_is_rejected" {
  command = plan

  variables {
    service      = null
    service_name = null
  }

  expect_failures = [var.service]
}

run "an_unknown_endpoint_type_is_rejected" {
  command = plan

  variables {
    endpoint_type = "PrivateLink"
  }

  expect_failures = [var.endpoint_type]
}

run "a_gateway_endpoint_for_an_unsupported_service_is_rejected" {
  command = plan

  variables {
    endpoint_type   = "Gateway"
    service         = "ssm"
    subnet_ids      = null
    route_table_ids = ["rtb-00000000000000001"]
  }

  expect_failures = [var.endpoint_type]
}

run "a_gateway_endpoint_without_route_tables_is_rejected" {
  command = plan

  variables {
    endpoint_type = "Gateway"
    service       = "s3"
    subnet_ids    = null
  }

  expect_failures = [var.endpoint_type]
}

run "an_interface_endpoint_without_subnets_is_rejected" {
  command = plan

  variables {
    subnet_ids = null
  }

  expect_failures = [var.endpoint_type]
}

run "defaults_build_an_interface_endpoint_with_private_dns" {
  command = apply

  assert {
    condition     = aws_vpc_endpoint.resource.vpc_endpoint_type == "Interface"
    error_message = "endpoint_type should default to Interface, which is the type that works for almost every service."
  }

  assert {
    condition     = aws_vpc_endpoint.resource.service_name == "com.amazonaws.us-east-1.ssm"
    error_message = "A short service name should be assembled against the current region."
  }

  assert {
    condition     = aws_vpc_endpoint.resource.private_dns_enabled
    error_message = "private_dns_enabled should default to true, which is what makes an endpoint transparent to existing SDK and CLI calls."
  }

  assert {
    condition     = length(aws_vpc_endpoint.resource.subnet_ids) == 2
    error_message = "Both subnets should be passed through to the interface."
  }

  assert {
    condition     = aws_vpc_endpoint.resource.vpc_id == "vpc-00000000000000001"
    error_message = "The VPC ID should be passed through."
  }
}

run "a_full_service_name_is_passed_through_untouched" {
  command = plan

  variables {
    service      = null
    service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0123456789abcdef0"
  }

  assert {
    condition     = aws_vpc_endpoint.resource.service_name == "com.amazonaws.vpce.us-east-1.vpce-svc-0123456789abcdef0"
    error_message = "A full service name should be used verbatim, so a PrivateLink service from another account works."
  }
}

run "a_gateway_endpoint_takes_route_tables_and_no_interface_settings" {
  command = plan

  variables {
    endpoint_type   = "Gateway"
    service         = "s3"
    subnet_ids      = null
    route_table_ids = ["rtb-00000000000000001", "rtb-00000000000000002"]
  }

  assert {
    condition     = length(aws_vpc_endpoint.resource.route_table_ids) == 2
    error_message = "Both route tables should receive the prefix-list route."
  }

  assert {
    condition     = aws_vpc_endpoint.resource.vpc_endpoint_type == "Gateway"
    error_message = "endpoint_type should be passed through as Gateway."
  }
}

run "private_dns_can_be_turned_off" {
  command = plan

  variables {
    private_dns_enabled = false
  }

  assert {
    condition     = aws_vpc_endpoint.resource.private_dns_enabled == false
    error_message = "private_dns_enabled should be passed through when disabled."
  }
}

run "an_endpoint_policy_is_passed_through" {
  command = plan

  variables {
    policy = "{\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
  }

  assert {
    condition     = aws_vpc_endpoint.resource.policy != null
    error_message = "An endpoint policy should be passed through, because it is what turns the endpoint into a boundary."
  }
}
