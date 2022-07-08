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
  region  = "us-east-1"
}
locals {
  name   = "code-stuff"
  tags = {
    Owner       = "user"
    Environment = "dev"
    App = "API"
  }
  environment = "dev"
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
    name             = "${local.name}"
    compute_platform = "Server"
}


resource "aws_codedeploy_deployment_group" "deploy_group" {
  app_name              = aws_codedeploy_app.example.name
  deployment_group_name = "${local.name}-DeploymentGroup${local.environment}"
  service_role_arn      = aws_iam_role.example.arn
  autoscaling_groups = ["${aws_autoscaling_group.autoscaling_group.name}"]
  }


resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}
resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-1a"

  tags = {
    Name = "Default subnet for us-east-1a"
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
data "aws_subnet" "subnet_1" {
  vpc_id = aws_default_vpc.default.id

  id = "subnet-02edba8757915bd1c"
}
data "aws_subnet" "subnet_2" {
  vpc_id = aws_default_vpc.default.id
  id = "subnet-084957adb65385567"
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "7.0.0"
  name = "API"
  subnets = [data.aws_subnet.subnet_1.id, data.aws_subnet.subnet_2.id]
  vpc_id = aws_default_vpc.default.id
  load_balancer_type = "application"
  security_groups    = [module.security_group.security_group_id]
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
      tags = {
        InstanceTargetGroupTag = "baz"
      }
    },
  ]
}

resource "aws_launch_configuration" "launch_configuration" {
  instance_type = "t2.micro"
  image_id =  data.aws_ami.amazon_linux.id

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_policy" "bat" {
  name                   = "foobar3-terraform-test"
  adjustment_type        = "ChangeInCapacity"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

resource "aws_autoscaling_group" "autoscaling_group" {
  target_group_arns = module.alb.target_group_arns  
  availability_zones = ["us-east-1a"]      
  name_prefix = "${local.name}-AutoscalingGroup"
  max_size                  = 5
  min_size                  = 1
  launch_configuration = "${aws_launch_configuration.launch_configuration.name}"
  depends_on = [module.alb]
}




