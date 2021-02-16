# Retrieve the latest version of the Amazon Linux 2 AMI
data "aws_ami" "linux2-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_launch_template" "launch-template" {
  name                   = "launch-template"
  image_id               = data.aws_ami.linux2-ami.image_id
  instance_type          = var.ec2-instance-type
  update_default_version = true
  user_data              = filebase64("${path.module}/bootstrap.sh")

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.backend-sg.id]
  }
}
