terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

}
provider "aws" {
  region = "eu-west-1"
  access_key = "AKIA53OXCSHNYCVF5RXS" 
  secret_key = "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"
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}


# Create Security Group (SG)
resource "aws_security_group" "allow_web" {
  name = "allow_web_traffic"
  description = "Allow inbound web traffic"

  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }

  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }

  ingress {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "SSH"
    from_port = 43
    to_port = 43
    protocol = "tcp"
  }

  egress  {
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "All networks allowed"
    from_port = 0
    to_port = 0
    protocol = "-1"
  }

  tags = {
    "Name" = "test-sg"
  }

}
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
    count = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"    

  user_data = "${file("install.sh")}"
  vpc_security_group_ids  = [ aws_security_group.allow_web.id]
  tags = {
   Name = "instance-${count.index}"
  }
}

# create target group 

resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}


# provides the ability to register instances and containers with a LB target group
resource "aws_lb_target_group_attachment" "test1" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.web[0].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "test2" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.web[1].id
  port             = 80
}
data "aws_subnet" "subnet" {
  vpc_id = aws_vpc.main.id


}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
 // subnets            = data.aws_subnet.subnet

  enable_deletion_protection = true

  
  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_security_group.allow_web.arn
  }
}