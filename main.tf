locals {
  puppy_image = "https://upload.wikimedia.org/wikipedia/commons/6/64/The_Puppy.jpg?20110313031847"
  kitty_image = "https://upload.wikimedia.org/wikipedia/commons/5/56/Kitty_Cat_%282265647870%29.jpg"
  hamster_image = "https://upload.wikimedia.org/wikipedia/commons/f/fa/Hamster_in_hand.jpg"
}


provider "aws" {
  region = "us-east-1" # Change this to your desired AWS region
}

module "vpc" {
  source              = "terraform-aws-modules/vpc/aws"
  version             = "5.2.0"
  
  name                = "my-vpc"
  cidr                = "10.0.0.0/16"
  azs                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets      = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway  = true
}

module "puppy_origin" {
  source              = "./modules/origin"
  name                = "puppy"
  ami                 = var.ami
  whitelisted_ip      = var.myip
  private_subnets     = module.vpc.private_subnets
  public_subnets      = module.vpc.public_subnets
  security_group_id   = module.vpc.default_security_group_id
  image_url           = local.puppy_image
  vpc_id              = module.vpc.vpc_id
  private_cidr_blocks = module.vpc.private_subnets_cidr_blocks
}

module "kitty_origin" {
  source              = "./modules/origin"
  name                = "kitty"
  ami                 = var.ami
  whitelisted_ip      = var.myip
  private_subnets     = module.vpc.private_subnets
  public_subnets      = module.vpc.public_subnets
  security_group_id   = module.vpc.default_security_group_id
  image_url           = local.kitty_image
  vpc_id              = module.vpc.vpc_id
  private_cidr_blocks = module.vpc.private_subnets_cidr_blocks
}
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.2.1"

  comment               = "My CloudFront distribution"

  origin = {
    puppy = {
      domain_name = module.puppy_origin.dns_name
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      }
    }

    kitty = {
      domain_name = module.kitty_origin.dns_name
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id           = "puppy"
    viewer_protocol_policy     = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/puppy/*"
      target_origin_id       = "puppy"
      viewer_protocol_policy = "allow-all"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = true
    },
    {
      path_pattern           = "/kitty/*"
      target_origin_id       = "kitty"
      viewer_protocol_policy = "allow-all"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = true
    }
  ]
}