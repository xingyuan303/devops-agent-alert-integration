output "sns_topic_arn" {
  description = "SNS Topic ARN — point your Grafana Alerting, Prometheus Alertmanager, or CloudWatch Alarms here"
  value       = aws_sns_topic.alerts.arn
}

output "feishu_notifier_function_name" {
  value = aws_lambda_function.feishu_notifier.function_name
}

output "investigation_notifier_function_name" {
  value = aws_lambda_function.investigation_notifier.function_name
}

output "eventbridge_rule_name" {
  value = aws_cloudwatch_event_rule.devops_agent_events.name
}
