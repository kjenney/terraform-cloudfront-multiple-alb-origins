data "aws_ami" "al2" {
 most_recent = true


 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }


 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.15.0"
  
  name                 = var.name
  source_ami           = data.aws_ami.al2.id
  instance_type        = "t3.micro"
  subnet_ids           = var.private_subnets
  security_group_ids   = [var.security_group_id]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.0.0"
  
  name               = var.name
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnets
  target_groups = {
    ex-instance = {
      name_prefix       = Var.name
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


