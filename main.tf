### Using providers

provider "aws" {
  region     = var.region
  access_key = var.accesskey
  secret_key = var.secretkey
}

######### 

######Chose terraform user
##resource "aws_iam_user" "terraform" {
##  name = "terraform"
##  path =   "/"                    ###file("${path.module}/id_rsa.pub")
##}


###Upload ssh pub key
resource "aws_key_pair" "root" {
  key_name   = "terraform"
  public_key = file("${path.module}/id_rsa.pub")
}


#Create VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  
  tags = {
      Name = "myvpc"
	  }
}

#Create subnet in VPC
resource "aws_subnet" "myvpc-sub1" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "myvpc-sub1"
  }
}

### Create gw for VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "maingw"
  }
}


#Create route table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
     Name = "public-crt"} 
}  

resource "aws_route_table_association" "myvpc-sub1-crt-main" {
  subnet_id      = aws_subnet.myvpc-sub1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "ssh-allowed" {
  name        = "ssh-allowed"
  description = "allow ssh connections"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "allow_all"
  }

  tags = {
    Name = "allow_ssh"
  }
}



### Create new VMs EC2 for kubernets

resource "aws_instance" "kub" {
  count = var.countvm                              #see variables to define count vm
  ami           = "ami-00e76d391403fc721"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.myvpc-sub1.id
  vpc_security_group_ids = [aws_security_group.ssh-allowed.id]
  key_name = aws_key_pair.root.id
}





output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.kub[*].public_ip
}


#
#
#
#### Rendering inventory	
#resource "local_file" "inventory" {
#  content = templatefile("${path.module}/inventory.tmpl",
#    {
#      ips = aws_route53_record.mezswarm[*].name
#    }
#  )
#  filename = "${path.module}/inventory.ini"
#}
#
#
#output "server_ip_testmez" {
#  value = digitalocean_droplet.swarm[*].ipv4_address
#}
#
#
#
#output "record" {
#  value = aws_route53_record.mezswarm[*].fqdn
#}
#
#


