provider "aws" {
  profile = "default"
  region  = var.region
}

resource "aws_api_gateway_rest_api" "MyDemoAPI" {
  name        = "MyDemoAPI"
  description = "This is my API for demonstration purposes"
}

resource "aws_api_gateway_resource" "MyDemoResource" {
  rest_api_id = aws_api_gateway_rest_api.MyDemoAPI.id
  parent_id   = aws_api_gateway_rest_api.MyDemoAPI.root_resource_id
  path_part   = "mydemoresource"
}

resource "aws_api_gateway_method" "MyDemoMethod" {
  rest_api_id   = aws_api_gateway_rest_api.MyDemoAPI.id
  resource_id   = aws_api_gateway_resource.MyDemoResource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "MyDemoIntegration" {
  rest_api_id          = aws_api_gateway_rest_api.MyDemoAPI.id
  resource_id          = aws_api_gateway_resource.MyDemoResource.id
  http_method          = aws_api_gateway_method.MyDemoMethod.http_method
  type                 = "MOCK"
  cache_namespace      = "foobar"
  timeout_milliseconds = 29000
  request_parameters = {
    "integration.request.header.X-Authorization" = "'static'"
  }

  # Transforms the incoming XML request to JSON
  request_templates = {
    "application/xml" = <<EOF
{
   "body" : $input.json('$')
}
EOF
  }
}
resource "aws_api_gateway_deployment" "MyDemoDeployment" {
  depends_on = [aws_api_gateway_integration.MyDemoIntegration]

  rest_api_id = aws_api_gateway_rest_api.MyDemoAPI.id
  stage_name  = "test"

  variables = {
    "answer" = "42"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_subnet_ids" "my-vpc-id" {
  vpc_id = var.vpc_id
}

data "aws_subnet" "subnets" {
  for_each = data.aws_subnet_ids.my-vpc-id.ids
  id       = each.value
}
resource "aws_lb" "my-nlb" {
  for_each = data.aws_subnet_ids.my-vpc-id.ids
  name               = "example"
  internal           = true
  load_balancer_type = "network"
  enable_deletion_protection = false
  subnets = data.aws_subnet.subnets[each.value]
  tags = {
    Environment = "production"
  }
}

resource "aws_api_gateway_vpc_link" "example" {
  name        = "example"
  description = "example description"
  target_arns = [aws_lb.my-nlb.arn]
}
