resource "aws_vpc" "main" {
  cidr_block = var.vpc-cidr-block

  tags = {
    Name = "main"
  }
}

# Retrieve the available AZ in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

# Creation of one public subnet per AZ
resource "aws_subnet" "public-subnets" {
  for_each = toset(local.available_az)

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value

  # dynamic computation of the cidr_block based on the number of available AZ in the current region
  # we keep some room for an additional subnet, thus the +1
  cidr_block = cidrsubnet(var.vpc-cidr-block, length(local.available_az) + 1, index(local.available_az, each.value))

  tags = {
    Name = "main-${each.value}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

# Retrieve the routing table of our VPC
data "aws_route_table" "selected" {
  vpc_id = aws_vpc.main.id
}

# Creation of the needed route to allow external traffic to/from our VPC
resource "aws_route" "igw-route" {
  route_table_id         = data.aws_route_table.selected.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
