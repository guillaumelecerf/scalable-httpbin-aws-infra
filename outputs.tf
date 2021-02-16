output "alb-url" {
  value = "Please connect to http://${aws_lb.alb.dns_name}/"
}
