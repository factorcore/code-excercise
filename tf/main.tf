terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-2"
}
locals {
  name   = "code-stuff"
  tags = {
    Owner       = "user"
    Environment = "dev"
    App = "API"
  }

  user_data = <<-EOT
  #!/bin/bash
  yum update -y aws-cfn-bootstrap
  yum install -y aws-cli
  function error_exit {
    /opt/aws/bin/cfn-signal -e 1 -r "$1"
    exit 1
  }
  # Install the AWS CodeDeploy Agent.
  cd /home/ec2-user/
  aws s3 cp 's3://aws-codedeploy-us-east-1/latest/codedeploy-agent.noarch.rpm' . || error_exit 'Failed to download AWS CodeDeploy Agent.'
  yum -y install codedeploy-agent.noarch.rpm || error_exit 'Failed to install AWS CodeDeploy Agent.' 
  /opt/aws/bin/cfn-init -s || error_exit 'Failed to run cfn-init.
  # All is well, so signal success.
  /opt/aws/bin/cfn-signal -e 0 -r "AWS CodeDeploy Agent setup complete."

  EOT

}
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_iam_role" "example" {
  name = "example-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.example.name
}

resource "aws_codedeploy_app" "example" {
  name = "API"
}

resource "aws_sns_topic" "example" {
  name = "example-topic"
}

resource "aws_codedeploy_deployment_group" "example" {
  app_name              = aws_codedeploy_app.example.name
  deployment_group_name = "example-group"
  service_role_arn      = aws_iam_role.example.arn

  ec2_tag_set {
    ec2_tag_filter {
      key   = "App"
      type  = "KEY_AND_VALUE"
      value = "API"
    }

    ec2_tag_filter {
      key   = "Environment"
      type  = "KEY_AND_VALUE"
      value = "dev"
    }
  }

  trigger_configuration {
    trigger_events     = ["DeploymentFailure"]
    trigger_name       = "example-trigger"
    trigger_target_arn = aws_sns_topic.example.arn
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  alarm_configuration {
    alarms  = ["my-alarm-name"]
    enabled = true
  }
}
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}
resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-2a"

  tags = {
    Name = "Default subnet for us-east-2a"
  }
}
module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Security group for example usage with EC2 instance"
  vpc_id      = aws_default_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]

  tags = local.tags
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "7.0.0"
  name = "API"
  subnets = aws_default_subnet.default_az1.id
  vpc_id = aws_default_vpc.default.id
  load_balancer_type = "application"
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
    ]
  target_groups = [
    {
      name_prefix          = "h1"
      backend_protocol     = "HTTP"
      backend_port         = 8080
      target_type          = "instance"
      deregistration_delay = 10
      protocol_version = "HTTP1"
      targets = {
        my_ec2 = {
          target_id = ec2-instance.id
          port      = 80
        }
      }
      tags = {
        InstanceTargetGroupTag = "baz"
      }
    },
  ]
}
resource "aws_codedeploy_app" "example" {
  compute_platform = "Server"
  name             = "example"
}

module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.0.0"
  associate_public_ip_address = false
  availability_zone = aws_default_subnet.default_az1.availability_zone
  capacity_reservation_specification = {
    capacity_reservation_preference = "open"
  }
  cpu_core_count       = 1
  cpu_threads_per_core = 1 
  ami = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  disable_api_termination = false
  ebs_optimized = true
  enclave_options_enabled = false
  get_password_data = false
  hibernation = false
  ipv6_address_count = 0
  ipv6_addresses = []
  key_name = "ssh-key"
  subnet_id = aws_default_subnet.default_az1.id
  tenancy = "default"
  user_data_base64 = base64encode(local.user_data)  
  vpc_security_group_ids = [module.security_group.security_group_id]
}



