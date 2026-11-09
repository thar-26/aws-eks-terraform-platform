resource "aws_sns_topic" "alerts" {
  name = "dev-alerts"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Count REJECT lines in the VPC flow logs
resource "aws_cloudwatch_log_metric_filter" "rejected_traffic" {
  name           = "dev-rejected-traffic"
  log_group_name = module.vpc.flow_log_group_name
  pattern        = "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, start, end, action=\"REJECT\", logstatus]"

  metric_transformation {
    name      = "RejectedFlows"
    namespace = "dev/VPC"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "rejected_traffic" {
  alarm_name          = "dev-vpc-rejected-traffic-high"
  alarm_description   = "Many rejected flows: check security groups, NACLs or firewall rules"
  namespace           = "dev/VPC"
  metric_name         = "RejectedFlows"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 100
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "node_cpu" {
  alarm_name          = "dev-eks-node-cpu-high"
  alarm_description   = "Average EKS node CPU above 80% for 10 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = module.eks.eks_managed_node_groups_autoscaling_group_names[0]
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ssm_instance_status" {
  alarm_name          = "dev-ssm-instance-status-check-failed"
  alarm_description   = "EC2 status check failed on the SSM instance"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = module.ssm_instance.instance_id
  }

  tags = local.tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "dev-platform"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EKS node CPU (%)"
          region = data.aws_region.current.region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.eks.eks_managed_node_groups_autoscaling_group_names[0]]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Rejected VPC flows"
          region = data.aws_region.current.region
          stat   = "Sum"
          period = 300
          metrics = [
            ["dev/VPC", "RejectedFlows"]
          ]
        }
      }
    ]
  })
}