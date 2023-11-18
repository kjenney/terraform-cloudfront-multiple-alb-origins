data "aws_ami" "al2" {
 most_recent = true


 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }


 filter {
   name   = "name"
   values = ["al2023-ami-2023*-kernel-*-x86_64"]
 }
}

module "security_group_instance" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.name}-ec2"
  description = "Security Group for EC2 Instance Egress"

  vpc_id      = var.vpc_id

  ingress_cidr_blocks      = ["10.0.0.0/16"]
  ingress_rules            = ["http-80-tcp"]
  egress_rules = ["all-all"]
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id = var.vpc_id

  endpoints = { for service in toset(["ssm", "ssmmessages", "ec2messages"]) :
    replace(service, ".", "_") =>
    {
      service             = service
      subnet_ids          = var.private_subnets
      private_dns_enabled = true
      tags                = { Name = "${var.name}-${service}" }
    }
  }

  create_security_group      = true
  security_group_name_prefix = "${var.name}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from subnets"
      cidr_blocks = var.private_cidr_blocks
    }
  }
}

data "template_file" "init" {
  template = "${file("${path.module}/user_data.sh.tpl")}"

  vars = {
    image_url   = var.image_url
    image_name  = var.name
  }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.5.0"
  
  name                            = var.name
  ami                             = var.ami != "" ? var.ami : data.aws_ami.al2.id
  instance_type                   = "t3.large"
  subnet_id                       = var.private_subnets[0]
  vpc_security_group_ids          = [module.security_group_instance.security_group_id]
  create_iam_instance_profile     = true
  iam_role_description            = "IAM role for EC2 instance"
  iam_role_policies               = {
    AmazonSSMManagedInstanceCore  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  user_data = data.template_file.init.rendered
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.2.0"
  
  name               = var.name
  vpc_id             = var.vpc_id
  load_balancer_type = "application"
  internal           = false
  enable_deletion_protection = false
  subnets            = var.public_subnets
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = var.whitelisted_ip != "" ? var.whitelisted_ip : "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "10.0.0.0/16"
    }
  }
  listeners           = {
    ex-http = {
      port            = 80
      protocol        = "HTTP"
      forward = {
        target_group_key = "ex-instance"
      }
    }
  }
  target_groups = {
    ex-instance = {
      name_prefix       = var.name
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      create_attachment = true
      target_id         = module.ec2_instance.id
    }
  }

  tags = {
    Environment = "Development"
    Project     = "Example"
  }
}


