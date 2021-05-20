provider "aws"{
    region = "eu-central-1"
}

resource "aws_instance" "create_example"{
    ami = "ami-0fe9519b61613bc94"
    instance_type = "t2.micro"

    tags = {
        Name = "example"
    }
}