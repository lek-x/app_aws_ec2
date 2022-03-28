### Using providers
provider "aws" {
  region     = var.region
  access_key = var.accesskey
  secret_key = var.secretkey
}


###Upload ssh pub key
resource "aws_key_pair" "root" {
  key_name   = "terraform"
  public_key = file("${path.module}/id_rsa.pub")
}

######NETWORK BLOCK ###########

#Create new VPC
resource "aws_vpc" "myvpc" {
  cidr_block           = "10.240.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = "true"
  enable_dns_support   = "true"

  tags = {
    Name = "vpc_${var.cluster_name}"
  }
}


#Create public subnet in VPC
resource "aws_subnet" "myvpc-sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.240.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-central-1a"

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "1",
	"kubernetes.io/role/elb" = "1"
  }
}

##Create Private subnet in VPC
#resource "aws_subnet" "myvpc-sub2" {
#  vpc_id                  = aws_vpc.myvpc.id
#  cidr_block              = "10.240.2.0/24"
#  availability_zone       = "eu-central-1a"
#
#  tags = {
#    "kubernetes.io/cluster/${var.cluster_name}" = "1",
#	
#  }
#}
#




### Create Internet Gateway for VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "maingw"
  }
}


#Create public route table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
  "kubernetes.io/cluster/${var.cluster_name}" = "1",
  "kubernetes.io/role/elb" = "1"
  }
}


##Create Private route table
#resource "aws_route_table" "private" {
#  vpc_id = aws_vpc.myvpc.id
#
#  route {
#    cidr_block = "10.240.2.0/24"
#  }
#  tags = {
#  "kubernetes.io/cluster/${var.cluster_name}" = "1"
#  }
#}

resource "aws_route_table_association" "myvpc-sub1-crt-main" {
  subnet_id      = aws_subnet.myvpc-sub1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "k8g" {
  name        = "k8group"
  description = "rules for k8s"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
 
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "kub"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
  }


  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "icmp"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
  }

  ingress {
    #cidr_blocks = [aws_vpc.myvpc.cidr_block]
    cidr_blocks = ["0.0.0.0/0"]
    description = "all inside subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  egress {
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
  }

  tags = {
    Name = "k8sg"
  }
}

resource "aws_eip" "eip_res" {
  count = var.countvm
  instance = "${element(aws_instance.kub[*].id, count.index)}"
  vpc = true
  tags = {
    Name = "eip_res${count.index}"
  }
}


#resource "aws_eip_association" "eip_assoc" {
#  instance_id   = "${element(aws_instance.kub[*].id, count.index)}"
#  allocation_id = "${element(aws_eip.eip_res[*].id,count.index)}"
#
#}




### Create new VMs EC2 for kubernets
resource "aws_instance" "kub" {
  count                       = var.countvm
  ami                         = "ami-0d527b8c289b4af7f"
  instance_type               = "t2.small"
  subnet_id                   = aws_subnet.myvpc-sub1.id
  #associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.k8g.id]
  key_name                    = aws_key_pair.root.id
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "1",
	 Name = "node${count.index}"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/id_rsa_private")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo '127.0.0.1 ${self.tags.Name}' | sudo tee -a /etc/hosts",
      "sudo hostnamectl set-hostname ${self.tags.Name}",
      "sudo sed -i 's/#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config",
      "sudo rm -rf /root/.ssh/authorized-keys",
      "sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/",
      "sudo chown root:root /root/.ssh/authorized_keys && sudo chmod 600 /root/.ssh/authorized_keys",
      "sudo service sshd restart"
    ]
  }


  root_block_device {
    delete_on_termination = true
    volume_size           = 10
    volume_type           = "gp3"
  }

}


###Show EC_ID
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.kub[*].id
}

###Show EC2_priv_ip
output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.kub[*].private_ip
}

###Show EC2_pub_ip
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.kub[*].public_ip
}


###Show EC2_hostname
output "instance_hostname" {
  description = "DNS address of the EC2 instance"
  value       = aws_instance.kub[*].private_dns
}


#### Rendering inventory (pub IP)
resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.tmpl",
    {
      ips = aws_instance.kub[*].public_ip
    }
  )
  filename = "${path.module}/inventory.ini"
}


##### Rendering inventory internal DNS
resource "local_file" "inventory_dns" {
  content = templatefile("${path.module}/inventory_dns.tmpl",{dns = aws_instance.kub[*].private_dns,ips = aws_instance.kub[*].public_ip})
  filename = "${path.module}/inventory.dns"
}




###Wait some time
resource "time_sleep" "wait" {
  depends_on = [local_file.inventory]

  create_duration = "10s"
}


### Run local bash script
resource "null_resource" "bash_script" {
  depends_on = [time_sleep.wait]
  provisioner "local-exec" {
    command     = "./readip.sh"
    interpreter = ["/bin/bash"]
  }
}


