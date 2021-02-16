# local variable to shorten the varname to use
locals {
  available_az = data.aws_availability_zones.available.names
}
