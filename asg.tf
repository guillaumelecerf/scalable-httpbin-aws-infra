resource "aws_autoscaling_group" "asg" {
  name                = "asg"
  vpc_zone_identifier = [for subnet in aws_subnet.public-subnets : subnet.id]

  # we want at least 2 instances in case of an AZ outage
  min_size = 2
  # we want a maximum of 2 instances per AZ
  max_size = 2 * length(local.available_az)

  launch_template {
    id      = aws_launch_template.launch-template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.target-group.arn]

  # Reduce cooldown to test faster, because our requests are served in less than 10sec
  default_cooldown = 10
}

# Scale our ASG in when its Average CPU Utilization gets over 80%
resource "aws_autoscaling_policy" "scale-out-by-one" {
  name                   = "scale-out-by-one"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
}

resource "aws_cloudwatch_metric_alarm" "asg-cpu-over-seventy" {
  alarm_name          = "asg-cpu-over-heighty"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitors EC2 CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.scale-out-by-one.arn]
}

# Scale our ASG out when its Average CPU Utilization gets below 20%
resource "aws_autoscaling_policy" "scale-in-by-one" {
  name                   = "scale-in-by-one"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
}

resource "aws_cloudwatch_metric_alarm" "asg-cpu-below-twenty" {
  alarm_name          = "asg-cpu-below-twenty"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "20"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitors EC2 CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.scale-in-by-one.arn]
}
