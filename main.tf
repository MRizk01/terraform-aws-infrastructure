provider "aws" {
  region     = "us-east-1"
  access_key = ""  # provide access key
  secret_key = ""  # provide secret key
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "15.1.0.0/16"
  tags = {
    Name = "rizk-vpc"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id             = aws_vpc.my_vpc.id
  cidr_block         = "15.1.1.0/24"
  availability_zone  = "us-east-1a"
  tags = {
    Name = "rizk-subnet-a"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id             = aws_vpc.my_vpc.id
  cidr_block         = "15.1.2.0/24"
  availability_zone  = "us-east-1b"
  tags = {
    Name = "rizk-subnet-b"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "rizk-internet-gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
  tags = {
    Name = "rizk-public-route-table"
  }
}

resource "aws_route_table_association" "subnet_a_association" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "subnet_b_association" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "rizk-instance-sg"
  }
}

resource "aws_instance" "instance1" {
  ami                  = "ami-0e86e20dae9224db8"
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu
              sudo docker pull nginx
              echo "<html><body><h1>Welcome to Instance 1</h1></body></html>" > index.html
              sudo docker run -d -p 80:80 -v $(pwd)/index.html:/usr/share/nginx/html/index.html nginx
              sudo docker pull jenkins/jenkins:lts
              sudo docker run --name jenkins -d -p 8080:8080 -p 50000:50000 --restart=on-failure -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts
              EOF
  tags = {
    Name = "rizk-instance1"
  }
}

resource "aws_instance" "instance2" {
  ami                  = "ami-0e86e20dae9224db8"
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.subnet_b.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu
              sudo docker pull nginx
              echo "<html><body><h1>Welcome to Instance 2</h1></body></html>" > index.html
              sudo docker run -d -p 80:80 -v $(pwd)/index.html:/usr/share/nginx/html/index.html nginx
              sudo docker pull jenkins/jenkins:lts
              sudo docker run --name jenkins -d -p 8080:8080 -p 50000:50000 --restart=on-failure -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts
              EOF
  tags = {
    Name = "rizk-instance2"
  }
}

resource "aws_lb" "my_alb" {
  name               = "rizk-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.instance_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  tags = {
    Name = "rizk-alb"
  }
}

resource "aws_lb_target_group" "my_target_group" {
  name     = "rizk-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name = "rizk-target-group"
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
  tags = {
    Name = "rizk-http-listener"
  }
}

resource "aws_lb_target_group_attachment" "instance1_attachment" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.instance1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "instance2_attachment" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.instance2.id
  port             = 80
}

resource "aws_ecr_repository" "my_ecr_repo" {
  name = "rizk-ecr-repo"
  tags = {
    Name = "rizk-ecr-repo"
  }
}
