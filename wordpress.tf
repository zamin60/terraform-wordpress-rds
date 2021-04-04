provider "aws" {
  region = "us-east-1"
}

#creating_vpc
resource "aws_vpc" "wordpressvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "wordpressvpc"
    purpose = "wordpress"
  }
enable_dns_hostnames = "true"
}

#creating_public_subnet

resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.wordpressvpc.id
  cidr_block = "10.0.1.0/24"
 availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet"
    purpose = "wordpress"
  }
}

#creating_private_subnet

resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.wordpressvpc.id
  cidr_block = "10.0.2.0/24"
availability_zone = "us-east-1b"

  tags = {
    Name = "private"
    purpose = "wordpress"
  }
}

#creating_securitygroup

resource "aws_security_group" "wordpresstask-sg" {
  name        = "wordpresstask-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.wordpressvpc.id
 
  ingress {
    description = "TLS from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = {
    Name = "wordpress-sg"
    purpose = "wordpress"
  }
 
}
 
#creating_internet-gateway

resource "aws_internet_gateway" "mywpigw" {
  vpc_id = aws_vpc.wordpressvpc.id
 
  tags = {
    Name = "mywpigw"
    purpose = "wordpress"
  }
}

#creating_route_table
 
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.wordpressvpc.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mywpigw.id
  }
  tags = {
    Name = "public-rt"
    purpose = "wordpress"
  }
}

#associating_route_table

resource "aws_route_table_association" "publicassociation" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id
}

#creating_keypair

resource "aws_key_pair" "mynewwpkey" {
  key_name   = "mynewwpkey"
  public_key = ""
}

#creating_asg

resource "aws_launch_configuration" "mylaunchconfiguration" {
  image_id               = "ami-0742b4e673072066f"
  instance_type          = "t2.micro"
  security_groups        = [aws_security_group.wordpresstask-sg.id]

  key_name               = "mynewwpkey"
  user_data = file("script.sh")

  lifecycle {
    create_before_destroy = true
  }
associate_public_ip_address = true
}

#Creating AutoScaling Group

resource "aws_autoscaling_group" "myasg" {
  launch_configuration = aws_launch_configuration.mylaunchconfiguration.id
 
  
 vpc_zone_identifier  = [aws_subnet.public-subnet.id]
  min_size = 1
  max_size = 2
  desired_capacity          = 1
  health_check_type = "ELB"
  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}

# autoscaling group attachment
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.myasg.id
  alb_target_group_arn   = aws_lb_target_group.wordpress-tg.arn
}

#Creating load-balancer

resource "aws_lb" "web_alb" {
  name = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.wordpresstask-sg.id
  ]
  subnets = [
    aws_subnet.public-subnet.id,
    aws_subnet.private-subnet.id
  ]
  tags = {
    purpose = "wordpress"
  }
  # cross_zone_load_balancing   = true
  
}

  # target group
  resource "aws_lb_target_group" "wordpress-tg" {
  name     = "tf-wordpress-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wordpressvpc.id
}

  resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.web_alb.arn
    port = 80
    protocol = "HTTP"

     default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress-tg.arn
  }
  }


resource "aws_db_subnet_group" "sb-grp" {
  name       = "main"
  subnet_ids = [aws_subnet.public-subnet.id, aws_subnet.private-subnet.id]

  tags = {
    Name = "My DB subnet group"
  }
}
# Launching RDS db instance

resource "aws_db_instance" "myrds" {
  allocated_storage    = 20
  max_allocated_storage = 100
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "wordpress"
  username             = ""
  password             = ""
  parameter_group_name = "default.mysql5.7"
  vpc_security_group_ids = [aws_security_group.wordpresstask-sg.id]

  availability_zone = "us-east-1a"
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.sb-grp.id
  
  skip_final_snapshot = true 

}