provider "aws" {
  region = "us-east-1"
}

# ---------------------- VPC ----------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# ---------------------- Subnets ----------------------
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

# ---------------------- Security Groups ----------------------
# Security Group for MongoDB EC2
resource "aws_security_group" "mongo_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Only allow access within the VPC
  }
}

# Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow Lambda to access MongoDB
  }
}

# ---------------------- IAM Role for Lambda ----------------------
resource "aws_iam_role" "lambda_role" {
  name = "lambda_vpc_role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ---------------------- EC2 Instance for MongoDB ----------------------
resource "aws_instance" "mongo_ec2" {
  ami             = "ami-05b10e08d247fb927"  # Amazon Linux 2 AMI (Check for latest)
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet_1.id
  security_groups = [aws_security_group.mongo_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras enable mongodb
              yum install -y mongodb-org
              systemctl start mongod
              systemctl enable mongod
            EOF

  tags = {
    Name = "MongoDB-Private-EC2"
  }
}

# ---------------------- Lambda Function ----------------------
resource "aws_lambda_function" "mongo_lambda" {
  function_name = "mongoLambda"
  runtime       = "nodejs18.x"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_role.arn
  timeout       = 10

  filename         = "lambda.zip"  # Upload your function code
  source_code_hash = filebase64sha256("lambda.zip")

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# ---------------------- VPC Endpoints for Lambda ----------------------
resource "aws_vpc_endpoint" "lambda" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.lambda"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  security_group_ids = [aws_security_group.lambda_sg.id]
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  security_group_ids = [aws_security_group.lambda_sg.id]
}

# ---------------------- Internet Gateway & NAT for Private Subnet ----------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.private_subnet_1.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_subnet_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}
