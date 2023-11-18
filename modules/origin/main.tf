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

  egress_rules = ["https-443-tcp"]
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

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.5.0"
  
  name                            = var.name
  ami                             = data.aws_ami.al2.id
  instance_type                   = "t3.large"
  subnet_id                       = var.private_subnets[0]
  vpc_security_group_ids          = [module.security_group_instance.security_group_id]
  create_iam_instance_profile     = true
  iam_role_description            = "IAM role for EC2 instance"
  iam_role_policies               = {
    AmazonSSMManagedInstanceCore  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

# module "alb" {
#   source  = "terraform-aws-modules/alb/aws"
#   version = "6.0.0"
  
#   name               = var.name
#   load_balancer_type = "application"
#   internal           = false
#   subnets            = var.public_subnets
#   target_groups = {
#     ex-instance = {
#       name_prefix       = Var.name
#       protocol          = "HTTP"
#       port              = 80
#       target_type       = "instance"
#       create_attachment = true
#       target_id         = module.ec2_instance.id
#     }
#   }

#   tags = {
#     Environment = "Development"
#     Project     = "Example"
#   }
# }


