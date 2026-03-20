# AWS provider configuration for LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    ec2            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    secretsmanager = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

# VPC Requester: The local network initiating communication
resource "aws_vpc" "requester_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "requester-vpc", Side = "Requester" }
}

# VPC Accepter: The remote network accepting communication
resource "aws_vpc" "accepter_vpc" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "accepter-vpc", Side = "Accepter" }
}

# Subnet Requester
resource "aws_subnet" "requester_subnet" {
  vpc_id            = aws_vpc.requester_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "requester-subnet" }
}

# Subnet Accepter
resource "aws_subnet" "accepter_subnet" {
  vpc_id            = aws_vpc.accepter_vpc.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "accepter-subnet" }
}

# VPC Peering Connection: The secure tunnel between VPCs
resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = aws_vpc.requester_vpc.id
  peer_vpc_id = aws_vpc.accepter_vpc.id
  auto_accept = true

  tags = { Name = "vpc-peering-lab" }
}

# Route Requester -> Accepter: Directs traffic through the peer
resource "aws_route" "requester_to_accepter" {
  route_table_id            = aws_vpc.requester_vpc.main_route_table_id
  destination_cidr_block    = aws_vpc.accepter_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# Route Accepter -> Requester: Enables return traffic
resource "aws_route" "accepter_to_requester" {
  route_table_id            = aws_vpc.accepter_vpc.main_route_table_id
  destination_cidr_block    = aws_vpc.requester_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# Security Group: Allows internal cross-VPC communication
resource "aws_security_group" "internal_sg" {
  name        = "peering-internal-sg"
  vpc_id      = aws_vpc.requester_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.accepter_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# VPC Endpoint (PrivateLink): Access Secrets Manager without internet traversal
resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id            = aws_vpc.requester_vpc.id
  service_name      = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type = "Interface"

  security_group_ids = [aws_security_group.internal_sg.id]
  subnet_ids         = [aws_subnet.requester_subnet.id]

  private_dns_enabled = true

  tags = { Name = "secrets-manager-privatelink" }
}

# Outputs: Key identifiers for network connectivity
output "requester_vpc_id" { value = aws_vpc.requester_vpc.id }
output "accepter_vpc_id" { value = aws_vpc.accepter_vpc.id }
output "peering_connection_id" { value = aws_vpc_peering_connection.peer.id }
output "privatelink_endpoint_id" { value = aws_vpc_endpoint.secrets_manager.id }
