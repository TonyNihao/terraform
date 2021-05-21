provider "aws"{
    region = "eu-central-1"
}


variable "server_port"{
    description = "Server port for web server"
    type = number
}


variable "lb_port"{
    description = "define load balancer port"
    type = number
    default = 80
}

// output "public_ip"{
//     value = aws_instance.create_example.public_ip
//     description = "EC2 public ip"
// }


// resource "aws_instance" "create_example"{
//     ami = "ami-05f7491af5eef733a"
//     instance_type = "t2.micro"
//     key_name = "ubuntu"
//     tags = {
//         name = "example"
//     }

//     user_data = file("user_data.sh")

//     vpc_security_group_ids = [aws_security_group.instance_httpd.id]
// }


output "lb_dns_name" {
    value = aws_lb.terraform_lb.dns_name
    description = "Load balancer DNS name"
}


data "aws_vpc" "default"{
    default = true
}


data "aws_subnet_ids" "default_subnet"{
    vpc_id = data.aws_vpc.default.id
    // filter{
    //     name = "tag:Name"
    //     values = ["default_subnet"]
    // }
}


resource "aws_lb" "terraform_lb"{
    name = "terraform-load-balancer"
    load_balancer_type = "application"
    subnets = data.aws_subnet_ids.default_subnet.ids
    security_groups = [aws_security_group.lb_sg.id]
}


resource "aws_lb_listener" "http"{
    load_balancer_arn = aws_lb.terraform_lb.arn
    port = 80
    protocol = "HTTP"
    default_action{
        type = "fixed-response"
        fixed_response{
            content_type = "text/plain"
            message_body = "error 404"
            status_code = 404
        }
    }
}


resource "aws_lb_target_group" "terraform_lb_tg"{
    name = "terraform-lb-target-group"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_subnet_ids.default_subnet.id
    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}


resource "aws_launch_configuration" "terraform_example"{
    image_id = "ami-05f7491af5eef733a"
    instance_type = "t2.micro"
    key_name = "ubuntu"
    security_groups = [aws_security_group.instance_httpd.id]
    user_data = file("user_data.sh")
    lifecycle {
        create_before_destroy = true
    }
    
}   


resource "aws_autoscaling_group" "terraform_asg" {
    launch_configuration = aws_launch_configuration.terraform_example.name
    min_size = 2
    max_size = 10
    vpc_zone_identifier = data.aws_subnet_ids.default_subnet.ids
    target_group_arns = [aws_lb_target_group.terraform_lb_tg.arn]
    health_check_type = "ELB"
    tag {
        key = "name"
        value = "terraform-example-asg"
        propagate_at_launch = true
    }
    
}


resource "aws_lb_listener_rule" "asg"{
    listener_arn = aws_lb_listener.http.arn
    priority = 100
    condition {
        path_pattern{
        values = ["*"]
        }
    }
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.terraform_lb_tg.arn

    }
}


resource "aws_security_group" "instance_httpd" {

    name = "instance-httpd-sg"

    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] 
    }

}


resource "aws_security_group" "lb_sg"{
    name = "load-balancer-sg"

    ingress{
        from_port = var.lb_port
        to_port = var.lb_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress{
        from_port = var.lb_port
        to_port = var.lb_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}