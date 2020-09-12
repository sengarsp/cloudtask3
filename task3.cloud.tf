provider "aws" {
  region = "ap-south-1"
  profile = "shyam"
}
resource "aws_vpc" "sengarspvpc" {
    cidr_block = "192.168.0.0/16"
    instance_tenancy = "default"


    tags = {
        Name = "sengarspvpc"
    }
}
// subnet can creates only after creating vpc
resource "aws_subnet" "public_subnet" {
    depends_on = [aws_vpc.sengarspvpc]
    vpc_id = aws_vpc.sengarspvpc.id
    cidr_block = "192.168.0.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
    tags = {
        Name =  "Public_Subnet"
    }
}
resource "aws_subnet" "private_subnet" {
    depends_on = [aws_vpc.sengarspvpc]
    vpc_id = aws_vpc.sengarspvpc.id
    cidr_block = "192.168.1.0/24"
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
    tags = {
        Name =  "Private_Subnet"
    }
}


// Creating Internet Getway
resource "aws_internet_gateway" "internet_getway" {
depends_on = [aws_vpc.sengarspvpc]
    vpc_id = aws_vpc.sengarspvpc.id
    tags = {
        Name = "Internet Getway"
    }
}
resource "aws_default_route_table" "routing_table" {
depends_on = [aws_internet_gateway.internet_getway,aws_vpc.sengarspvpc]
    default_route_table_id = aws_vpc.sengarspvpc.default_route_table_id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet_getway.id
    }
    tags = {
        Name = "Route_table"
    }
}
//routing accociation with subnet1 making it public
resource "aws_route_table_association" "routing_table_asson" {
    depends_on = [aws_default_route_table.routing_table,aws_subnet.public_subnet]
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_vpc.sengarspvpc.default_route_table_id
}
resource "tls_private_key" "key1" {
 algorithm = "RSA"
 rsa_bits = 4096
}
resource "local_file" "key2" {
 content = "${tls_private_key.key1.private_key_pem}"
 filename = "task1_key.pem"
 file_permission = 0400
}
resource "aws_key_pair" "key3" {
 key_name = "task1_key"
 public_key = "${tls_private_key.key1.public_key_openssh}"
}
//Creating Security group for bostion hos
resource "aws_security_group" "bostion_host_security_grp"{
depends_on = [aws_vpc.sengarspvpc]
    name        = "bostion_host_security_grp"
    vpc_id      = aws_vpc.sengarspvpc.id
    ingress{
           description = "For login to bostion host from anywhere"
           from_port   = 22
           to_port     = 22
           protocol    = "TCP"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks  = ["::/0"]
      }
    egress{
           from_port   = 0
           to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
      }


    tags ={
           Name = "Security_Group_Bostion_host"
      }
}


//creating security group for wordpress


resource "aws_security_group" "wordpress_security_grp"{
depends_on = [aws_vpc.sengarspvpc,aws_security_group.bostion_host_security_grp]
    name        = "wordpress_security_grp"
    vpc_id      = aws_vpc.sengarspvpc.id
    ingress{
           description = "For connecting to WordPress from outside world"
           from_port   = 80
           to_port     = 80
           protocol    = "TCP"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks  = ["::/0"]
      }
    ingress{
           description = "Only bostion host can connect to WordPress using ssh"
           from_port   = 22
           to_port     = 22
           protocol    = "TCP"
           security_groups=[aws_security_group.bostion_host_security_grp.id]
           ipv6_cidr_blocks  = ["::/0"]
      }
    ingress{
           description = "icmp from VPC"
           from_port   = -1
           to_port     = -1
           protocol    = "icmp"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks =  ["::/0"]
      }
    egress{
           from_port   = 0
           to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks =  ["::/0"]
  }


    tags ={
           Name = "Security_Group_WordPress"
      }
}


resource "aws_security_group" "mysql_security_grp"{
depends_on = [aws_vpc.sengarspvpc,aws_security_group.wordpress_security_grp]
    name        = "mysqlsecuritygrp"
    vpc_id      = aws_vpc.sengarspvpc.id
    ingress{
           description = "WordPress can connect to MySql"
           from_port   = 3306
           to_port     = 3306
           protocol    = "TCP"
           security_groups=[aws_security_group.wordpress_security_grp.id]
      }


    ingress{
           description = "Only web ping sql from public subnet"
           from_port   = -1
           to_port     = -1
           protocol    = "icmp"
           security_groups=[aws_security_group.wordpress_security_grp.id]
           ipv6_cidr_blocks=["::/0"]
      }
    ingress{
           description = "Only bostion host can connect to MySql using ssh"
           from_port   = 22
           to_port     = 22
           protocol    = "TCP"
           security_groups=[aws_security_group.bostion_host_security_grp.id]
           ipv6_cidr_blocks  = ["::/0"]
      }
     egress{
           from_port   = 0
           to_port     = 0
           protocol    = "-1"
           cidr_blocks = ["0.0.0.0/0"]
           ipv6_cidr_blocks =  ["::/0"]
  }


    tags ={
           Name = "Security_Group_MySql"
      }
}
resource "aws_instance" "wordpress_instance" {
    depends_on = [aws_security_group.wordpress_security_grp]
    ami = "ami-0fab75b03b2c2152d"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.wordpress_security_grp.id]
    key_name = "task1_key"
    subnet_id = aws_subnet.public_subnet.id
    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = "${tls_private_key.key1.private_key_pem}"
        host     = "${aws_instance.web.public_ip}"
    }
    tags = {
        Name = "WordPress_instance"
    }
}
resource "aws_instance" "bostion_host_instance"{
depends_on = [aws_security_group.bostion_host_security_grp]
    ami     = "ami-08706cb5f68222d09" 
    instance_type   ="t2.micro"
    vpc_security_group_ids =[aws_security_group.bostion_host_security_grp.id]
    key_name    ="task1_key"                
    subnet_id = aws_subnet.public_subnet.id
    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = "${tls_private_key.key1.private_key_pem}"
        host     = "${aws_instance.web.public_ip}"
    }
    tags ={
        Name = "Bositon_Host_instance"
      }
}
resource "aws_instance" "mysql_instance"{
depends_on = [aws_security_group.mysql_security_grp]
    ami     = "ami-08706cb5f68222d09" 
    instance_type   ="t2.micro"
    vpc_security_group_ids =[aws_security_group.mysql_security_grp.id]
    key_name    ="task1_key"        
    subnet_id = aws_subnet.private_subnet.id
    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = "${tls_private_key.key1.private_key_pem}"
        host     = "${aws_instance.web.public_ip}"
    }
    tags ={
        Name = "MySql_instance"
      }
}
resource "null_resource" "writing_ip_to_local_file"{


    depends_on = [
    aws_instance.wordpress_instance,
    aws_instance.mysql_instance,
    aws_instance.bostion_host_instance,
    ]
    provisioner "local-exec"{
          command = "echo WORDPRESS_Public_IP:${aws_instance.wordpress_instance.public_ip}=======WORDPRESS_Private_IP:${aws_instance.wordpress_instance.private_ip}======Bostion_OS_Public_IP:${aws_instance.bostion_host_instance.public_ip}======MySql_Private_IP:${aws_instance.mysql_instance.private_ip} >  ip_address_of_instances.txt "      
      
     }
   }