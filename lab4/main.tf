terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.13.1"
    }
  }
}

provider "aws" {
  region        = "ap-northeast-1"      # tokyo
}

# VPC 생성
resource "aws_vpc" "lab4_vpc" {
  cidr_block    = "10.4.0.0/16"
  tags = {
    Name = "LAB4 PVC"
  }
}

# 새로운 서브넷 생성
resource "aws_subnet" "public_1a" {
  vpc_id = aws_vpc.lab4_vpc.id
  cidr_block = "10.4.1.0/24"
  availability_zone = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id = aws_vpc.lab4_vpc.id
  cidr_block = "10.4.3.0/24"
  availability_zone = "ap-northeast-1c"
  map_public_ip_on_launch = true #공인주소 매핑
  tags = {
    Name = "Public Subnet 1c"
  }
}

# 새로운 IGW
resource "aws_internet_gateway" "lab4_igw" {
  vpc_id = aws_vpc.lab4_vpc.id
  tags = {
    Name = "LAB4 IGW"
  }
}

# 라우팅 테이블 추가
resource "aws_route_table" "lab4_vpc_public" {
  vpc_id = aws_vpc.lab4_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab4_igw.id
  }
  tags = {
    Name = "Public Subnet Route"
  }
}

# 서브넷에 라우팅 추가하기
resource "aws_route_table_association" "route_add_public_1a" {
  subnet_id = aws_subnet.public_1a.id
  route_table_id = aws_route_table.lab4_vpc_public.id
}

resource "aws_route_table_association" "route_add_public_1c" {
  subnet_id = aws_subnet.public_1c.id
  route_table_id = aws_route_table.lab4_vpc_public.id
}

# 보안 그룹 설정하기
resource "aws_security_group" "allow_http" {
  name = "allow_http"
  description = "permit web traffic"
  vpc_id = aws_vpc.lab4_vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Permit web and ssh traffic"
  }
}


# 인스턴스 배포
resource "aws_launch_configuration" "web" {
  image_id = "ami-044dbe71ee2d3c59e"    # amazon linux 5.10
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_http.id]
  key_name = "webtest"
  user_data = <<-EOF
    #!/bin/bash
    sudo yum -y install httpd
    echo "Hello,World" | sudo tee /var/www/html/index.html
    sudo systemctl enable httpd
    sudo systemctl start httpd
    EOF

  lifecycle {
    create_before_destroy = true
  }
}

# 로드 밸런서
resource "aws_security_group" "elb_http" {
  name        = "elb_http"
  description = "Allow HTTP traffic to instances through Elastic Load Balancer"
  vpc_id = aws_vpc.lab4_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow HTTP through ELB Security Group"
  }
}
resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.elb_http.id
  ]
  subnets = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1c.id
  ]
  cross_zone_load_balancing   = true
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
}

# 오토 스케일링 그룹
resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"
  min_size             = 2
  max_size             = 4

  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]
  launch_configuration = aws_launch_configuration.web.name
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity = "1Minute"
  vpc_zone_identifier  = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1c.id
  ]

  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }
}

# elb_dns 노출
output "elb_dns_name" {
  value = aws_elb.web_elb.dns_name
}

# 오토 스케일 동적 정책 수립
resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "60"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.web_policy_up.arn ]
}
