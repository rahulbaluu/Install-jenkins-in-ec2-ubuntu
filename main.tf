resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "Default subnet for us-west-2"
  }
}

resource "aws_security_group" "example" {
  name        = "aws_security_group"
  description = "acess to port 22, 8080 and 9000"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = -1
  }

  tags   = {
    Name = "jenkins server"
  }
}

data "aws_ami" "ubuntu" {

    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["amazon"]
}

resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.example.id]
  key_name               = "demo"

  tags = {
    Environment = "dev"
    Name = "jenkins Ubuntu server"
  }
}
# an empty resource block
resource "null_resource" "name" {
  # ssh into the ec2 instance 
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/Downloads/demo.pem")
    host        =  aws_instance.ec2_instance.public_ip
  }
  # copy the install_jenkins.sh file from your computer to the ec2 instance 
  provisioner "file" {
    source      = "ubuntu-ec2-requirement-installation.sh"
    destination = "/tmp/ubuntu-ec2-requirement-installation.sh"
  }

  # set permissions and run the install_jenkins.sh file
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/ubuntu-ec2-requirement-installation.sh",
      "sudo /bin/bash /tmp/ubuntu-ec2-requirement-installation.sh",
    ]
  }

  # wait for ec2 to be created
  depends_on = [aws_instance.ec2_instance]
}

# print the url of the jenkins server
output "jenkins_url" {
  value     = join ("", ["http://", aws_instance.ec2_instance.public_dns, ":", "8080" ])
}

output "sonarqube_url" {
  value     = join ("", ["http://", aws_instance.ec2_instance.public_ip, ":", "9000"])
}
#If get error while applying "terraform apply", Please try "terraform apply" secound time code will execute without error.